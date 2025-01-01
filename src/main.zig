const std = @import("std");
const zap = @import("zap");
const fs = std.fs;
const json = std.json;
const path = std.fs.path;
const time = std.time;
const crypto = std.crypto;
const base64 = std.base64;
const Sha256 = crypto.hash.sha2.Sha256;
const extensions = @import("extensions.zig");

const ServerConfig = struct {
    port: u16 = 3000,
    host: []u8 = undefined,
    threads: u8 = 2,
    workers: u8 = 1,
    max_clients: u32 = 100000,
    features: struct {
        hot_reload: bool = true,
        compression: bool = true,
        logging: bool = true,
    } = .{},
    security: struct {
        cors_enabled: bool = true,
        cors_origins: []const []const u8 = &.{"*"},
        cors_methods: []const []const u8 = &.{ "GET", "POST", "OPTIONS" },
        cors_headers: []const []const u8 = &.{"Content-Type"},
        cache_control: bool = true,
        cache_max_age: u32 = 3600,
        headers: struct {
            x_frame_options: []const u8 = "DENY",
            x_content_type_options: []const u8 = "nosniff",
            x_xss_protection: []const u8 = "1; mode=block",
            strict_transport_security: []const u8 = "max-age=31536000; includeSubDomains",
            referrer_policy: []const u8 = "strict-origin-when-cross-origin",
        } = .{},
        csrf_protection: bool = true,
        csrf_token_length: u8 = 32,
        request_timeout_ms: u32 = 30000,
        max_request_size: usize = 10485760,
        trusted_proxies: []const []const u8 = &.{
            "127.0.0.1",
            "::1",
        },
        content_security_policy: []const u8 = "default-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; script-src 'self' 'unsafe-inline';",
        permissions_policy: []const u8 = "geolocation=(), camera=(), microphone=()",
    } = .{},
    monitoring: struct {
        enabled: bool = true,
        endpoint: []const u8 = "/metrics",
        collect_memory_stats: bool = true,
        collect_request_stats: bool = true,
    } = .{},
    compression: struct {
        level: u8 = 6,
        min_size: u32 = 1024,
        types: []const []const u8 = &.{
            "text/html",
            "text/css",
            "text/javascript",
            "application/javascript",
            "application/json",
            "image/svg+xml",
            "text/plain",
            "text/xml",
            "application/xml",
        },
        brotli_enabled: bool = true,
        brotli_quality: u8 = 4,
    } = .{},
    extensions: struct {
        tor: extensions.TorExtension.TorConfig = .{
            .enabled = false,
            .hidden_service = true,
            .port = 9050,
            .control_port = 9051,
            .control_password = "",
            .virtual_port = 80,
            .service_dir = "./hidden_service",
            .allowed_ports = &[_]u16{ 80, 443 },
        },
        i2p: extensions.I2PExtension.I2PConfig = .{
            .enabled = false,
            .sam_address = "127.0.0.1",
            .sam_port = 7656,
            .tunnel_name = "zapped-service",
            .tunnel_length = 3,
            .inbound_length = 3,
            .outbound_length = 3,
            .service_dir = "./i2p_service",
        },
    } = .{},
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
var config: ServerConfig = .{};

const RateLimiter = struct {
    requests: u32 = 0,
    last_reset: i64 = 0,
    const WINDOW_SECONDS: u32 = 60;
    const MAX_REQUESTS: u32 = 100;
};

var rate_limiters: std.StringHashMap(RateLimiter) = undefined;

fn initRateLimiting() !void {
    rate_limiters = std.StringHashMap(RateLimiter).init(allocator);
}

fn isRateLimited(identifier: []const u8) bool {
    const current_time = time.timestamp();

    if (rate_limiters.getPtr(identifier)) |limiter| {
        if (current_time - limiter.last_reset >= RateLimiter.WINDOW_SECONDS) {
            limiter.*.requests = 0;
            limiter.*.last_reset = current_time;
        }
        limiter.*.requests += 1;
        return limiter.*.requests > RateLimiter.MAX_REQUESTS;
    } else {
        // Create new rate limiter entry
        const limiter = RateLimiter{
            .requests = 1,
            .last_reset = current_time,
        };
        rate_limiters.put(identifier, limiter) catch return false;
        return false;
    }
}

fn isPathSafe(requested_path: []const u8) bool {
    // Prevent access to hidden files and sensitive extensions
    const forbidden_patterns = [_][]const u8{
        "..", // Directory traversal
        "/.git",
        "/.env",
        ".toml",
        ".zig",
        ".json",
        "/.github",
        "/src",
        "/zig-cache",
        "/zig-out",
    };

    // Check if path contains any forbidden patterns
    for (forbidden_patterns) |pattern| {
        if (std.mem.indexOf(u8, requested_path, pattern) != null) {
            return false;
        }
    }

    // Only allow serving from permitted directories
    const allowed_prefixes = [_][]const u8{
        "/public/",
        "/css/",
        "/js/",
        "/fonts/",
        "/images/",
        "/assets/",
        "index.html",
    };

    // Path must start with one of the allowed prefixes
    for (allowed_prefixes) |prefix| {
        if (std.mem.startsWith(u8, requested_path, prefix) or std.mem.eql(u8, requested_path, prefix)) {
            return true;
        }
    }

    return false;
}

fn loadConfig() !void {
    const config_file = try fs.cwd().openFile("zapped.json", .{});
    defer config_file.close();

    const content = try config_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
    defer parsed.deinit();

    const root = parsed.value;

    // Parse server section
    if (root.object.get("server")) |server| {
        if (server.object.get("port")) |port| config.port = @intCast(port.integer);
        if (server.object.get("host")) |host| {
            // Free old host if it exists
            allocator.free(config.host);
            // Allocate and copy new host
            config.host = try allocator.dupe(u8, host.string);
        }
        if (server.object.get("threads")) |threads| config.threads = @intCast(threads.integer);
        if (server.object.get("workers")) |workers| config.workers = @intCast(workers.integer);
        if (server.object.get("max_clients")) |max_clients| config.max_clients = @intCast(max_clients.integer);
    }

    // Parse features section
    if (root.object.get("features")) |features| {
        if (features.object.get("hot_reload")) |hot_reload| config.features.hot_reload = hot_reload.bool;
        if (features.object.get("compression")) |compression| config.features.compression = compression.bool;
        if (features.object.get("logging")) |logging| config.features.logging = logging.bool;
    }

    // Parse security section
    if (root.object.get("security")) |security| {
        if (security.object.get("cors_enabled")) |cors_enabled| config.security.cors_enabled = cors_enabled.bool;
        if (security.object.get("cache_control")) |cache_control| config.security.cache_control = cache_control.bool;
        if (security.object.get("cache_max_age")) |cache_max_age| config.security.cache_max_age = @intCast(cache_max_age.integer);

        // Parse headers subsection
        if (security.object.get("headers")) |headers| {
            if (headers.object.get("x_frame_options")) |x_frame| config.security.headers.x_frame_options = x_frame.string;
            if (headers.object.get("x_content_type_options")) |x_content| config.security.headers.x_content_type_options = x_content.string;
            if (headers.object.get("x_xss_protection")) |x_xss| config.security.headers.x_xss_protection = x_xss.string;
            if (headers.object.get("strict_transport_security")) |hsts| config.security.headers.strict_transport_security = hsts.string;
            if (headers.object.get("referrer_policy")) |referrer| config.security.headers.referrer_policy = referrer.string;
        }
    }

    // Parse compression section
    if (root.object.get("compression")) |compression| {
        if (compression.object.get("level")) |level| config.compression.level = @intCast(level.integer);
        if (compression.object.get("min_size")) |min_size| config.compression.min_size = @intCast(min_size.integer);
    }
}

fn sendFile(r: zap.Request, file_path: []const u8, content_type: []const u8) !void {
    const full_path = try std.fs.path.join(allocator, &.{ "public", file_path });
    defer allocator.free(full_path);

    const file = std.fs.cwd().openFile(full_path, .{}) catch |err| {
        std.debug.print("Failed to open file '{s}': {}\n", .{ full_path, err });
        r.setStatus(.not_found);
        try r.sendBody("404 - File Not Found");
        return error.FileNotFound;
    };
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;

    const contents = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(contents);

    try r.setHeader("Content-Type", content_type);

    // Skip compression for images
    const is_image = std.mem.startsWith(u8, content_type, "image/");
    if (is_image) {
        try r.setHeader("Content-Length", try std.fmt.allocPrint(allocator, "{d}", .{file_size}));
        try r.sendBody(contents);
        return;
    }

    // Add cache headers for static files
    if (config.security.cache_control) {
        const cache_header = try std.fmt.allocPrint(allocator, "public, max-age={d}", .{config.security.cache_max_age});
        defer allocator.free(cache_header);
        try r.setHeader("Cache-Control", cache_header);
    }

    try r.sendBody(contents);
}

fn getMimeType(file_path: []const u8) []const u8 {
    // Images
    if (std.mem.endsWith(u8, file_path, ".png")) return "image/png";
    if (std.mem.endsWith(u8, file_path, ".jpg") or std.mem.endsWith(u8, file_path, ".jpeg")) return "image/jpeg";
    if (std.mem.endsWith(u8, file_path, ".gif")) return "image/gif";
    if (std.mem.endsWith(u8, file_path, ".svg")) return "image/svg+xml";
    if (std.mem.endsWith(u8, file_path, ".ico")) return "image/x-icon";
    if (std.mem.endsWith(u8, file_path, ".webp")) return "image/webp";

    // Other types...
    if (std.mem.endsWith(u8, file_path, ".html")) return "text/html; charset=utf-8";
    if (std.mem.endsWith(u8, file_path, ".css")) return "text/css; charset=utf-8";
    if (std.mem.endsWith(u8, file_path, ".js")) return "application/javascript; charset=utf-8";
    if (std.mem.endsWith(u8, file_path, ".woff")) return "font/woff";
    if (std.mem.endsWith(u8, file_path, ".woff2")) return "font/woff2";
    if (std.mem.endsWith(u8, file_path, ".ttf")) return "font/ttf";
    if (std.mem.endsWith(u8, file_path, ".eot")) return "application/vnd.ms-fontobject";
    if (std.mem.endsWith(u8, file_path, ".otf")) return "font/otf";

    return "application/octet-stream";
}

fn handleOptions(r: zap.Request) !void {
    try r.setHeader("Access-Control-Allow-Origin", "*");
    try r.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    try r.setHeader("Access-Control-Allow-Headers", "Content-Type");
    try r.sendBody("");
}

// Add environment check
const Environment = enum {
    development,
    production,
};

// Default to production for safety
var current_env: Environment = .production;

// Add security context
const SecurityContext = struct {
    csrf_tokens: std.StringHashMap([]const u8),
    ip_blacklist: std.StringHashMap(i64),
    failed_attempts: std.StringHashMap(u32),

    fn init() !SecurityContext {
        return SecurityContext{
            .csrf_tokens = std.StringHashMap([]const u8).init(allocator),
            .ip_blacklist = std.StringHashMap(i64).init(allocator),
            .failed_attempts = std.StringHashMap(u32).init(allocator),
        };
    }

    fn deinit(self: *SecurityContext) void {
        var token_it = self.csrf_tokens.iterator();
        while (token_it.next()) |entry| {
            allocator.free(entry.value_ptr.*);
        }
        self.csrf_tokens.deinit();
        self.ip_blacklist.deinit();
        self.failed_attempts.deinit();
    }
};

var security_ctx: SecurityContext = undefined;

// Enhanced security checks
fn securityCheck(r: zap.Request) !bool {
    // Get client IP from headers
    const ip = r.getHeader("X-Forwarded-For") orelse r.getHeader("X-Real-IP") orelse "unknown";

    // Check if IP is blacklisted
    if (security_ctx.ip_blacklist.get(ip)) |timestamp| {
        const ban_duration = 3600; // 1 hour ban
        if (time.timestamp() - timestamp < ban_duration) {
            r.setStatus(.forbidden);
            try r.sendBody("Access denied");
            return false;
        } else {
            // Remove from blacklist after ban duration
            _ = security_ctx.ip_blacklist.remove(ip);
        }
    }

    // Rate limiting
    if (isRateLimited(ip)) {
        const attempts = security_ctx.failed_attempts.get(ip) orelse 0;
        try security_ctx.failed_attempts.put(ip, attempts + 1);

        // Blacklist IP after too many failed attempts
        if (attempts > 10) {
            try security_ctx.ip_blacklist.put(ip, time.timestamp());
        }

        r.setStatus(.too_many_requests);
        try r.sendBody("Too many requests");
        return false;
    }

    // Validate request size
    if (r.getHeader("Content-Length")) |length_str| {
        const length = std.fmt.parseInt(usize, length_str, 10) catch return true;
        if (length > config.security.max_request_size) {
            r.setStatus(.payload_too_large);
            try r.sendBody("Request too large");
            return false;
        }
    }

    return true;
}

// Updated security headers function to use config values
fn setSecurityHeaders(r: zap.Request) !void {
    // Basic security headers with static values
    try r.setHeader("X-Frame-Options", "DENY");
    try r.setHeader("X-Content-Type-Options", "nosniff");
    try r.setHeader("X-XSS-Protection", "1; mode=block");
    try r.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
    try r.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
    try r.setHeader("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'");
    try r.setHeader("Permissions-Policy", "geolocation=(), camera=(), microphone=()");

    // Basic CORS headers
    if (config.security.cors_enabled) {
        try r.setHeader("Access-Control-Allow-Origin", "*");
        try r.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        try r.setHeader("Access-Control-Allow-Headers", "Content-Type");
    }

    // Simple cache control
    if (config.security.cache_control) {
        try r.setHeader("Cache-Control", "public, max-age=3600");
    }
}

// Request context for tracking timing and metrics
const RequestContext = struct {
    start_time: i64,
    path: []const u8,
    method: []const u8,
    size: usize = 0,
    status: u16 = 200,

    fn recordMetrics(self: RequestContext) void {
        if (!config.monitoring.enabled) return;

        const duration = time.timestamp() - self.start_time;
        metrics.requests_total += 1;
        metrics.response_times.append(@intCast(duration)) catch return;

        metrics.status_codes.put(self.status, (metrics.status_codes.get(self.status) orelse 0) + 1) catch return;
    }
};

// Add monitoring endpoint
fn handleMetrics(r: zap.Request) !void {
    if (!config.monitoring.enabled) {
        r.setStatus(.not_found);
        return;
    }

    const uptime = time.timestamp() - metrics.start_time;
    var buf: [4096]u8 = undefined;
    const stats = try std.fmt.bufPrint(&buf,
        \\# HELP requests_total Total number of HTTP requests made.
        \\# TYPE requests_total counter
        \\requests_total {d}
        \\# HELP errors_total Total number of HTTP errors.
        \\# TYPE errors_total counter
        \\errors_total {d}
        \\# HELP uptime_seconds Server uptime in seconds.
        \\# TYPE uptime_seconds gauge
        \\uptime_seconds {d}
        \\# HELP memory_bytes Memory usage in bytes.
        \\# TYPE memory_bytes gauge
        \\memory_bytes {d}
        \\
    , .{
        metrics.requests_total,
        metrics.errors_total,
        uptime,
        metrics.memory_usage,
    });

    try r.setHeader("Content-Type", "text/plain; version=0.0.4");
    try r.sendBody(stats);
}

// Add these structures after ServerMetrics
const LoadMonitor = struct {
    cpu_usage: f64 = 0,
    memory_usage: f64 = 0,
    open_connections: usize = 0,
    request_queue_size: usize = 0,
    last_check: i64 = 0,

    const CRITICAL_CPU_THRESHOLD: f64 = 90.0;
    const CRITICAL_MEMORY_THRESHOLD: f64 = 90.0;
    const MAX_REQUEST_QUEUE: usize = 10000;
    const CHECK_INTERVAL_MS: i64 = 1000;

    fn init() LoadMonitor {
        return LoadMonitor{
            .last_check = 0,
        };
    }

    fn start(self: *LoadMonitor) void {
        self.last_check = time.timestamp();
    }

    fn updateMetrics(self: *LoadMonitor) !void {
        const current_time = time.timestamp();
        if (current_time - self.last_check < CHECK_INTERVAL_MS / 1000) return;

        // Update CPU usage
        self.cpu_usage = try getCpuUsage();

        // Update memory usage
        self.memory_usage = try getMemoryUsage();

        self.last_check = current_time;
    }

    fn isOverloaded(self: LoadMonitor) bool {
        return self.cpu_usage > CRITICAL_CPU_THRESHOLD or
            self.memory_usage > CRITICAL_MEMORY_THRESHOLD or
            self.request_queue_size > MAX_REQUEST_QUEUE;
    }
};

const OverloadProtection = struct {
    backoff_factor: f64 = 1.0,
    requests_dropped: usize = 0,
    last_reset: i64 = 0,

    const MAX_BACKOFF: f64 = 60.0;
    const BACKOFF_MULTIPLIER: f64 = 1.5;
    const RESET_INTERVAL_SEC: i64 = 300;

    fn shouldDropRequest(self: *OverloadProtection) bool {
        const current_time = time.timestamp();

        // Reset backoff periodically
        if (current_time - self.last_reset > RESET_INTERVAL_SEC) {
            self.backoff_factor = 1.0;
            self.requests_dropped = 0;
            self.last_reset = current_time;
        }

        // Probabilistic drop based on backoff factor
        const drop_probability = 1.0 - (1.0 / self.backoff_factor);
        const random_val = @as(f64, @floatFromInt(std.crypto.random.int(u32) % 100)) / 100.0;

        if (random_val < drop_probability) {
            self.requests_dropped += 1;
            self.backoff_factor = @min(self.backoff_factor * BACKOFF_MULTIPLIER, MAX_BACKOFF);
            return true;
        }

        return false;
    }
};

var load_monitor = LoadMonitor.init();
var overload_protection = OverloadProtection{};

fn getCpuUsage() !f64 {
    const stat_file = try std.fs.openFileAbsolute("/proc/stat", .{});
    defer stat_file.close();

    var buffer: [1024]u8 = undefined;
    const bytes_read = try stat_file.readAll(&buffer);
    const content = buffer[0..bytes_read];

    var lines = std.mem.split(u8, content, "\n");
    if (lines.next()) |cpu_line| {
        var values = std.mem.tokenize(u8, cpu_line, " ");
        _ = values.next(); // Skip "cpu" label

        var total: u64 = 0;
        var idle: u64 = 0;
        var i: usize = 0;

        while (values.next()) |value| {
            const val = try std.fmt.parseInt(u64, value, 10);
            if (i == 3) idle = val;
            total += val;
            i += 1;
        }

        return (1.0 - @as(f64, @floatFromInt(idle)) / @as(f64, @floatFromInt(total))) * 100.0;
    }

    return 0;
}

fn getMemoryUsage() !f64 {
    const meminfo_file = try std.fs.openFileAbsolute("/proc/meminfo", .{});
    defer meminfo_file.close();

    var buffer: [4096]u8 = undefined;
    const bytes_read = try meminfo_file.readAll(&buffer);
    const content = buffer[0..bytes_read];

    var total: u64 = 0;
    var available: u64 = 0;

    var lines = std.mem.split(u8, content, "\n");
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "MemTotal:")) {
            var tokens = std.mem.tokenize(u8, line, " ");
            _ = tokens.next(); // Skip "MemTotal:"
            if (tokens.next()) |value| {
                total = try std.fmt.parseInt(u64, value, 10);
            }
        } else if (std.mem.startsWith(u8, line, "MemAvailable:")) {
            var tokens = std.mem.tokenize(u8, line, " ");
            _ = tokens.next(); // Skip "MemAvailable:"
            if (tokens.next()) |value| {
                available = try std.fmt.parseInt(u64, value, 10);
            }
        }
    }

    return (1.0 - @as(f64, @floatFromInt(available)) / @as(f64, @floatFromInt(total))) * 100.0;
}

// Update the on_request function to include overload protection
fn on_request(r: zap.Request) void {
    load_monitor.updateMetrics() catch {};

    // Check for overload conditions
    if (load_monitor.isOverloaded()) {
        if (overload_protection.shouldDropRequest()) {
            r.setStatus(.service_unavailable);
            r.sendBody("Server is experiencing high load, please try again later") catch return;
            return;
        }
    }

    // Increment connection counter
    load_monitor.open_connections += 1;
    defer load_monitor.open_connections -= 1;

    // Initialize request context for metrics
    const request_ctx = RequestContext{
        .start_time = time.timestamp(),
        .path = r.path orelse "",
        .method = r.method orelse "",
    };
    defer request_ctx.recordMetrics();

    // Security checks
    if (securityCheck(r)) |passed| {
        if (!passed) {
            metrics.errors_total += 1;
            return;
        }
    } else |err| {
        std.debug.print("Security check failed: {}\n", .{err});
        metrics.errors_total += 1;
        return;
    }

    // Set security headers
    setSecurityHeaders(r) catch |err| {
        std.debug.print("Failed to set security headers: {}\n", .{err});
        metrics.errors_total += 1;
        return;
    };

    if (r.path) |the_path| {
        // Add metrics endpoint handling
        if (std.mem.eql(u8, the_path, "/metrics")) {
            handleMetrics(r) catch |err| {
                std.debug.print("Error serving metrics: {}\n", .{err});
                r.setStatus(.internal_server_error);
                r.sendBody("Internal Server Error") catch return;
            };
            return;
        }

        // Serve index.html for root path
        if (std.mem.eql(u8, the_path, "/")) {
            sendFile(r, "index.html", "text/html; charset=utf-8") catch |err| {
                std.debug.print("Error serving index: {}\n", .{err});
                serveNotFound(r);
            };
            return;
        }

        // Handle static files
        if (std.mem.startsWith(u8, the_path, "/public/") or
            std.mem.startsWith(u8, the_path, "/css/") or
            std.mem.startsWith(u8, the_path, "/js/") or
            std.mem.startsWith(u8, the_path, "/fonts/") or
            std.mem.startsWith(u8, the_path, "/images/"))
        {
            const file_path = the_path[1..];
            const mime_type = getMimeType(file_path);
            sendFile(r, file_path, mime_type) catch |err| {
                std.debug.print("Error serving file '{s}': {}\n", .{ file_path, err });
                serveNotFound(r);
            };
            return;
        }

        // Handle assets directory explicitly
        if (std.mem.startsWith(u8, the_path, "/assets/")) {
            const file_path = the_path[1..]; // Remove leading slash
            const mime_type = getMimeType(file_path);
            sendFile(r, file_path, mime_type) catch |err| {
                std.debug.print("Error serving asset '{s}': {}\n", .{ file_path, err });
                serveNotFound(r);
            };
            return;
        }

        // Handle unmatched routes
        serveNotFound(r);
    }
}

fn serveNotFound(r: zap.Request) void {
    sendFile(r, "404.html", "text/html; charset=utf-8") catch |err| {
        std.debug.print("Error serving 404 page: {}\n", .{err});
        r.setStatus(.not_found);
        r.sendBody("404 - Not Found") catch return;
    };
}

fn handleApiRequest(r: zap.Request) !void {
    // Set JSON content type for API responses
    try r.setHeader("Content-Type", "application/json; charset=utf-8");

    if (r.path) |the_path| {
        if (std.mem.eql(u8, the_path, "/api/data")) {
            const response = try std.json.stringifyAlloc(allocator, .{
                .message = "Hello from API",
                .timestamp = time.timestamp(),
            }, .{});
            defer allocator.free(response);
            try r.sendBody(response);
            return;
        }
    }

    r.setStatus(.not_found);
    try r.sendBody("{\"error\": \"API endpoint not found\"}");
}

fn printServerBanner(server_config: ServerConfig) void {
    std.debug.print("\n=================================\n", .{});
    std.debug.print("🚀 Zap Server Starting\n", .{});
    std.debug.print("=================================\n", .{});
    std.debug.print("📡 Listening on: http://{s}:{d}\n", .{ server_config.host, server_config.port });
    std.debug.print("🔥 Hot Reloading: Enabled\n", .{});
    std.debug.print("🔒 Security Headers: Enabled\n", .{});
    std.debug.print("🌐 CORS: Enabled\n", .{});
    std.debug.print("📦 Cache Control: Enabled\n", .{});
    std.debug.print("=================================\n\n", .{});
}

fn initConfig() !ServerConfig {
    return ServerConfig{
        .host = try allocator.dupe(u8, "127.0.0.1"),
        .port = 3000,
        .threads = 2,
        .workers = 1,
        .max_clients = 100000,
        // ... other defaults ...
    };
}

// Add these structures for monitoring
const ServerMetrics = struct {
    requests_total: u64 = 0,
    errors_total: u64 = 0,
    bytes_sent: u64 = 0,
    response_times: std.ArrayList(u64),
    status_codes: std.AutoHashMap(u16, u64),
    memory_usage: u64 = 0,
    start_time: i64,

    fn init() !ServerMetrics {
        return ServerMetrics{
            .response_times = std.ArrayList(u64).init(allocator),
            .status_codes = std.AutoHashMap(u16, u64).init(allocator),
            .start_time = time.timestamp(),
        };
    }

    fn deinit(self: *ServerMetrics) void {
        self.response_times.deinit();
        self.status_codes.deinit();
    }
};

var metrics: ServerMetrics = undefined;

// CSRF token generation and validation
fn generateCsrfToken() ![32]u8 {
    var token: [32]u8 = undefined;
    try std.crypto.random.bytes(&token);
    return token;
}

fn validateCsrfToken(token: []const u8, stored_token: []const u8) bool {
    return crypto.utils.timingSafeEql(u8, token, stored_token);
}

var tor_extension: extensions.TorExtension = undefined;
var i2p_extension: extensions.I2PExtension = undefined;

pub fn main() !void {
    // Initialize security context
    security_ctx = try SecurityContext.init();
    defer security_ctx.deinit();

    // Initialize metrics
    metrics = try ServerMetrics.init();
    defer metrics.deinit();

    // Initialize config with defaults
    config = try initConfig();
    defer allocator.free(config.host);

    try loadConfig();
    try initRateLimiting();

    var listener = zap.HttpListener.init(.{
        .port = config.port,
        .on_request = on_request,
        .log = config.features.logging,
        .max_clients = config.max_clients,
    });
    try listener.listen();

    printServerBanner(config);

    // Start memory monitoring if enabled
    if (config.monitoring.enabled and config.monitoring.collect_memory_stats) {
        const timer_ms = 60000; // Update every minute
        _ = try std.Thread.spawn(.{}, struct {
            fn run() !void {
                while (true) {
                    // Use process resident memory as a simple metric
                    const pid = std.os.linux.getpid();
                    const statm_path = try std.fmt.allocPrint(allocator, "/proc/{d}/statm", .{pid});
                    defer allocator.free(statm_path);

                    if (std.fs.openFileAbsolute(statm_path, .{})) |file| {
                        defer file.close();
                        var buffer: [128]u8 = undefined;
                        if (file.reader().readUntilDelimiter(&buffer, '\n')) |line| {
                            var it = std.mem.split(u8, line, " ");
                            _ = it.next(); // Skip total
                            if (it.next()) |resident| {
                                // Convert pages to bytes (usually 4KB pages)
                                const pages = std.fmt.parseInt(usize, resident, 10) catch 0;
                                metrics.memory_usage = pages * 4096;
                            }
                        } else |_| {}
                    } else |_| {}

                    std.time.sleep(timer_ms * 1000 * 1000);
                }
            }
        }.run, .{});
    }

    // Initialize extensions
    tor_extension = try extensions.TorExtension.init(allocator, config.extensions.tor);
    i2p_extension = try extensions.I2PExtension.init(allocator, config.extensions.i2p);

    defer {
        tor_extension.deinit();
        i2p_extension.deinit();
    }

    load_monitor.start();

    zap.start(.{
        .threads = config.threads,
        .workers = config.workers,
    });
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
