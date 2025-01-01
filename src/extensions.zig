const std = @import("std");
const net = std.net;
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const crypto = std.crypto;

pub const TorExtension = struct {
    allocator: mem.Allocator,
    control_socket: ?net.Stream,
    onion_address: ?[]u8,
    config: TorConfig,

    pub const TorConfig = struct {
        enabled: bool,
        hidden_service: bool,
        port: u16,
        control_port: u16,
        control_password: []const u8,
        virtual_port: u16,
        service_dir: []const u8,
        allowed_ports: []const u16,
    };

    pub fn init(allocator: mem.Allocator, config: TorConfig) !TorExtension {
        if (!config.enabled) {
            return TorExtension{
                .allocator = allocator,
                .control_socket = null,
                .onion_address = null,
                .config = config,
            };
        }

        var extension = TorExtension{
            .allocator = allocator,
            .control_socket = null,
            .onion_address = null,
            .config = config,
        };

        try extension.connectToControl();
        if (config.hidden_service) {
            try extension.setupHiddenService();
        }

        return extension;
    }

    fn connectToControl(self: *TorExtension) !void {
        const addr = try net.Address.parseIp4("127.0.0.1", self.config.control_port);
        self.control_socket = try net.tcpConnectToAddress(addr);

        if (self.config.control_password.len > 0) {
            // Authenticate with control port
            const auth_cmd = try std.fmt.allocPrint(self.allocator, "AUTHENTICATE \"{s}\"\r\n", .{self.config.control_password});
            defer self.allocator.free(auth_cmd);
            _ = try self.control_socket.?.write(auth_cmd);
        }
    }

    fn setupHiddenService(self: *TorExtension) !void {
        // Create hidden service directory
        try fs.cwd().makePath(self.config.service_dir);

        // Setup hidden service
        const hs_cmd = try std.fmt.allocPrint(self.allocator, "ADD_ONION NEW:BEST Port={d},{d}\r\n", .{ self.config.virtual_port, self.config.port });
        defer self.allocator.free(hs_cmd);

        _ = try self.control_socket.?.write(hs_cmd);
        // Read and parse response for onion address
        var buf: [1024]u8 = undefined;
        const response = try self.control_socket.?.read(&buf);
        if (response > 0) {
            // Parse onion address from response
            // Format: "250-ServiceID=<onion_address>"
            if (std.mem.indexOf(u8, buf[0..response], "ServiceID=")) |index| {
                const start = index + "ServiceID=".len;
                const end = std.mem.indexOf(u8, buf[start..response], "\r\n") orelse response;
                self.onion_address = try self.allocator.dupe(u8, buf[start .. start + end]);
            }
        }
    }

    pub fn deinit(self: *TorExtension) void {
        if (self.control_socket) |socket| {
            socket.close();
        }
        if (self.onion_address) |addr| {
            self.allocator.free(addr);
        }
    }
};

pub const I2PExtension = struct {
    allocator: mem.Allocator,
    sam_socket: ?net.Stream,
    destination_key: ?[]u8,
    config: I2PConfig,

    pub const I2PConfig = struct {
        enabled: bool,
        sam_address: []const u8,
        sam_port: u16,
        tunnel_name: []const u8,
        tunnel_length: u8,
        inbound_length: u8,
        outbound_length: u8,
        service_dir: []const u8,
    };

    pub fn init(allocator: mem.Allocator, config: I2PConfig) !I2PExtension {
        if (!config.enabled) {
            return I2PExtension{
                .allocator = allocator,
                .sam_socket = null,
                .destination_key = null,
                .config = config,
            };
        }

        var extension = I2PExtension{
            .allocator = allocator,
            .sam_socket = null,
            .destination_key = null,
            .config = config,
        };

        try extension.connectToSAM();
        try extension.createTunnel();

        return extension;
    }

    fn connectToSAM(self: *I2PExtension) !void {
        const addr = try net.Address.parseIp4(self.config.sam_address, self.config.sam_port);
        self.sam_socket = try net.tcpConnectToAddress(addr);

        // SAM handshake
        const hello_cmd = "HELLO VERSION MIN=3.1 MAX=3.1\n";
        _ = try self.sam_socket.?.write(hello_cmd);
    }

    fn createTunnel(self: *I2PExtension) !void {
        try fs.cwd().makePath(self.config.service_dir);

        const tunnel_cmd = try std.fmt.allocPrint(self.allocator, "SESSION CREATE STYLE=STREAM ID={s} DESTINATION=TRANSIENT " ++
            "inbound.length={d} outbound.length={d} " ++
            "i2cp.fastReceive=true\n", .{
            self.config.tunnel_name,
            self.config.inbound_length,
            self.config.outbound_length,
        });
        defer self.allocator.free(tunnel_cmd);

        _ = try self.sam_socket.?.write(tunnel_cmd);
        // Read and store destination key
        var buf: [2048]u8 = undefined;
        const response = try self.sam_socket.?.read(&buf);
        if (response > 0) {
            if (std.mem.indexOf(u8, buf[0..response], "DESTINATION=")) |index| {
                const start = index + "DESTINATION=".len;
                const end = std.mem.indexOf(u8, buf[start..response], "\n") orelse response;
                self.destination_key = try self.allocator.dupe(u8, buf[start .. start + end]);
            }
        }
    }

    pub fn deinit(self: *I2PExtension) void {
        if (self.sam_socket) |socket| {
            socket.close();
        }
        if (self.destination_key) |key| {
            self.allocator.free(key);
        }
    }
};
