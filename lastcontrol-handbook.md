## LastControl Usage

You can download lastcontrol script from the link below.<br>

---

```bash
wget https://raw.githubusercontent.com/eesmer/LastControl/master/lastcontrol.sh

```
```bash
bash lastcontrol.sh --help
```

---
**Usage:** lastcontrol.sh [OPTION] <br>
<br>
**Optional arguments:**<br>

| Option              | Description                                                              |
| ------------------- | -------------------------------------------------------------------------|
| --help, -h          | Show this help message                                                   |
| --report-localhost  | It checks the server (local machine) you are running on                  |
| --report-remotehost | It checks the remote server                                              |
| --report-allhost	  | Generates reports from all remote servers in Host List                   |
| --server-install    | Installs LastControl Server to perform remote server control             |
| --add-host          | LastControl SSH Key is added to the server and included in the Host List |
| --remove-host       | LastContol SSH Key is deleted and removed from the Host list             |
| --host-list		      | List of Added Hosts                                                      |
| ------------------- | -------------------------------------------------------------------------|

<br>

**Example:** <br>
bash lastcontrol.sh --report-localhost <br>
bash lastcontrol.sh --server-install <br>
bash lastcontrol.sh --report-remotehost [TARGETHOST] [PORTNUMBER] <br>

---

```bash
bash lastcontrol.sh --localhost
```
---
