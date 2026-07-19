## Lightweight Linux Fleet Reporting & Telemetry Platform

![alt text](docs/lastcontrol_logo.png "LastControl Logo")

---

LastControl is a reporting and telemetry platform that runs on Linux machines using a TLS-enabled agent.
Unlike large-scale enterprise monitoring systems, it aims to provide a fast-to-deploy, scalable, minimal, and easy-to-understand infrastructure.

### Key Highlights
- Lightweight agent-based reporting platform
- TLS-secured communication
- Vendor-aware CVE intelligence
- Historical inventory and telemetry
- Web dashboard
- Multi-distribution support

![LastControl](https://img.shields.io/badge/LastControl-Linux%20System%20Reporter-1e3a8a?style=for-the-badge&logo=linux&logoColor=green&labelColor=0f172a&color=darkblue) <br>

---
LastControl provides multiple reporting pages including inventory, software updates, installed packages, users, services, networking, historical telemetry and vendor-aware CVE exposure.

#### Supported Distros
- Ubuntu
- RHEL / Rocky / Alma
- Debian
- Oracle Linux

---

### Vendor Security Matching

LastControl does not compare only package versions. <br>
Instead it correlates installed packages with official vendor security advisories.
This approach significantly reduces false positives and follows the security status published by distribution vendors.

#### Supported security sources;
- [Debian Security Tracker](https://security-tracker.debian.org/)
- [Ubuntu OVAL](https://security-metadata.canonical.com/oval/)
- [Red Hat Security Data API](https://access.redhat.com/hydra/rest/securitydata)

#### Future vendors
- Oracle Linux
- SUSE

![alt text](docs/SS1-CVE-Exposure.png "CVE Page")

---

### Installation
The installation has been tested on **Debian 13 Trixie**. Use the latest version of **Debian** for the server. <br>
(Server installation has not been tested on Ubuntu. You can try it if you like.) <br>
```
wget https://raw.githubusercontent.com/eesmer/LastControl/refs/heads/main/LastControl-ServerInstaller.sh
```
```
bash LastControl-ServerInstaller.sh
```

### Access to Web Interface
```
http://SERVER_IP
Username: admin
Password: lastcontrol
```
### Agent Installation
The server generates a custom installer:
```
http://SERVER_IP/download-agent
```
```
/usr/local/lastcontrol/dist/lastcontrol-agent_installer.sh
```
Copy the installer to the target machine and run:
```
bash lastcontrol-agent_installer.sh
```
The agent will:
- Install required dependencies
- Install reporting scripts
- Install TLS certificates
- Configure systemd timer
- Start periodic reporting

---
