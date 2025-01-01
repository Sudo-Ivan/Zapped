I tend to forget these commands, so I'm writing them down here:

# 1. Enter the container shell
```
docker exec -it zapped-privacy /bin/bash
podman exec -it zapped-privacy /bin/bash
```

# 2. Check if I2P daemon is running
```
docker exec zapped-privacy ps aux | grep i2pd
podman exec zapped-privacy ps aux | grep i2pd
```

# 3. View I2P configuration
```
docker exec zapped-privacy cat /etc/i2pd/i2pd.conf
podman exec zapped-privacy cat /etc/i2pd/i2pd.conf
```

# 4. Watch I2P logs
```
docker exec zapped-privacy tail -f /var/log/i2pd/i2pd.log
podman exec zapped-privacy tail -f /var/log/i2pd/i2pd.log
```

# 5. Check if the address files exist
```
docker exec zapped-privacy ls -la /var/lib/i2pd/zapped-keys.dat*
podman exec zapped-privacy ls -la /var/lib/i2pd/zapped-keys.dat*
```

# 6. View tunnel configuration
```
docker exec zapped-privacy cat /etc/i2pd/tunnels.conf
podman exec zapped-privacy cat /etc/i2pd/tunnels.conf
```

# 7. Check network ports and connections
```
docker exec zapped-privacy netstat -tulpn | grep i2pd
podman exec zapped-privacy netstat -tulpn | grep i2pd
```

# 8. Check system resources used by I2P
```
docker exec zapped-privacy top -n 1 | grep i2pd
podman exec zapped-privacy top -n 1 | grep i2pd
```

# 9. Test SAM bridge connectivity
```
docker exec zapped-privacy nc -zv 127.0.0.1 7656
podman exec zapped-privacy nc -zv 127.0.0.1 7656
```

# 11. Check file ownership and permissions of key directories
```
docker exec zapped-privacy ls -la /var/lib/i2pd/
docker exec zapped-privacy ls -la /etc/i2pd/
podman exec zapped-privacy ls -la /var/lib/i2pd/
podman exec zapped-privacy ls -la /etc/i2pd/
```
