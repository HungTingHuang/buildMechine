# Windows VcXsrv + VirtualBox NAT + Docker + Godot GUI Guide

This guide explains how to run VcXsrv on Windows and display the Godot GUI from a Linux VM using VirtualBox NAT, including a Docker container running inside that VM.

## Network layout

```text
Godot (Docker container)
        |
        v
Linux VM (Docker bridge, 172.17.x.x)
        |
        v
VirtualBox NAT host alias (typically 10.0.2.2:6000)
        |
        v
VcXsrv (Windows, X11 display :0)
```

VirtualBox NAT commonly uses `10.0.2.2` as the guest-to-host address. X11 display `:0` uses TCP port `6000`. Verify that this address works in your setup with the connection test below.

## 1. Install and launch VcXsrv on Windows

1. Download and install VcXsrv from the [official VcXsrv download page](https://sourceforge.net/projects/vcxsrv/).
2. Search for and launch **XLaunch** from the Windows Start menu. The installer usually installs `xlaunch.exe`; a common path is:

   ```text
   C:\Program Files\VcXsrv\xlaunch.exe
   ```

3. Configure XLaunch:
   - **Multiple windows**
   - **Display number**: `0`
   - **Start no client**
   - Enable Clipboard if desired.
4. Save the configuration and start the server. If Windows Firewall prompts you, allow access only on trusted **Private networks**, not Public networks.

### X server access control

Do not disable X11 access control casually. Only consider checking **Disable access control** for isolated, trusted local testing. Anyone who can connect to the X server may be able to interact with your X session, read its screen, or simulate input. Never use this option on a public or untrusted network, and do not create a firewall rule that exposes the server to all networks.

A safer approach is to keep access control enabled and configure X11 cookie authentication (for example, with `xauth`). The matching cookie must also be made available to the Docker container; setting `DISPLAY` alone does not provide authentication.

## 2. Test connectivity from the Linux VM to Windows

Install `nc` in the Linux VM (not inside the Docker container). On Debian/Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y netcat-openbsd
```

Test the VirtualBox NAT host alias:

```sh
nc -vz 10.0.2.2 6000
```

If the output says `succeeded`, the VM can reach VcXsrv's X11 port. If it fails, check that VcXsrv is running, Windows Firewall allows the connection, and the VirtualBox network mode is NAT.

Common interface addresses:

- `10.0.2.15` on `enp0s3`: the Linux VM's address on the VirtualBox NAT network.
- `172.17.0.1` on `docker0`: the Docker bridge address on the Linux VM.
- `10.0.2.2`: a commonly used VirtualBox NAT address for guest-to-host connections.

`10.0.2.2` usually does not appear in the VM's `ifconfig` output. Use the `nc` test to verify it.

## 3. Test connectivity from the Docker container to VcXsrv

Check that the Docker container can reach the same X11 port:

```sh
docker run --rm hedaz:godot_dev nc -vz 10.0.2.2 6000
```

If the image does not include `nc`, add `netcat-openbsd` to the image and rebuild it, or use another TCP testing tool that is already installed. Confirm this test succeeds before troubleshooting Godot.

If the VM can connect but the container cannot, check Docker networking and firewall rules for outbound container traffic. This is not VirtualBox inbound port forwarding: the container is initiating a connection to the host's X server.

## 4. Launch the Godot GUI from Docker

After the container connectivity test succeeds, run this command in the Linux VM:

```sh
docker run --rm \
  --user root \
  -v "$HOME":"$HOME" \
  -w "$HOME" \
  -e DISPLAY=10.0.2.2:0.0 \
  hedaz:godot_dev \
  /tmp/godot/bin/godot.linuxbsd.editor.x86_64 --display-driver x11
```

Adjust these values for your environment:

- `hedaz:godot_dev`: your Docker image.
- `/tmp/godot/bin/godot.linuxbsd.editor.x86_64`: the actual path to the Godot executable inside the container.
- `-v "$HOME":"$HOME"`: mounts the VM's home directory at the same path in the container. If your project is elsewhere, mount its directory and update `-w` accordingly.
- `--display-driver x11`: explicitly selects X11 so Godot does not try to connect to a Wayland display that is unavailable in the container.

To open a project in the editor, add this option to the end of the command:

```text
--path /path/to/project/inside/container
```

For example, if the project is mounted at `/workspace/game`:

```sh
docker run --rm \
  --user root \
  -v "$HOME/projects/game:/workspace/game" \
  -w /workspace/game \
  -e DISPLAY=10.0.2.2:0.0 \
  hedaz:godot_dev \
  /tmp/godot/bin/godot.linuxbsd.editor.x86_64 --display-driver x11 --path /workspace/game
```

## 5. Troubleshooting

### `X11 Display is not available`

- Confirm VcXsrv is running on Windows.
- Confirm both the VM and Docker container can run `nc -vz 10.0.2.2 6000` successfully.
- Confirm `DISPLAY` is set to `10.0.2.2:0.0`.
- Check Windows Firewall and VcXsrv's X11 access control.

### `XDG_RUNTIME_DIR is invalid` or Wayland connection errors

The container usually does not have the host's Wayland socket. These messages mean Godot tried to use Wayland; add `--display-driver x11` to force X11. Arbitrarily setting `XDG_RUNTIME_DIR` inside the container does not create a working Wayland display.

### Missing shared libraries such as `libfontconfig.so.1`

This means the container is missing a system library required by Godot. It is separate from X11 network connectivity. Install the required runtime packages in the image for its Linux distribution, then rebuild the image.

### `host.docker.internal` does not resolve inside the container

This hostname is primarily provided by Docker Desktop. In this setup, Docker runs inside a Linux VM, so use the verified VirtualBox NAT host alias `10.0.2.2`.

## Security reminder

X11 grants connected clients significant control over the desktop session. Test only in a trusted environment, restrict the Windows Firewall rule to the appropriate network, and close VcXsrv when finished. Never expose X server TCP port 6000 to a public network.
