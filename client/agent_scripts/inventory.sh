#!/bin/bash

[ -f /etc/os-release ] && . /etc/os-release
DISTRO=$PRETTY_NAME
KERNEL=$(uname -r)

get_internal_ip() {
    hostname -I | awk '{print $1}'
}
get_external_ip() {
    curl -s --max-time 2 ifconfig.me || echo "N/A"
}
get_disk_list() {
    if command -v lsblk >/dev/null; then
        lsblk -dno NAME,SIZE | tr '\n' ',' | sed 's/,$//'
    else
        awk '{if(NR>2) print $4 " " $3}' /proc/partitions | tr '\n' ','
    fi
}
get_virt_control() {
    systemd-detect-virt 2>/dev/null || echo "physical"
}
get_gpu() {
    if command -v lspci >/dev/null; then
        lspci | grep -iE 'vga|3d|display' | cut -d: -f3 | xargs || echo "None"
    else
        echo "N/A"
    fi
}
get_bios() {
    if [ -r /sys/class/dmi/id/bios_vendor ]; then
        echo "$(cat /sys/class/dmi/id/bios_vendor) - $(cat /sys/class/dmi/id/bios_version)"
    else
        echo "Permission Denied"
    fi
}
get_last_boot() {
	#LAST_BOOT=$(who -b | awk '{print $3,$4}')
	who -b | awk '{print $3,$4}'
}
get_bios_vendor() {
	dmidecode -s bios-vendor
}
get_bios_version() {
	dmidecode -s bios-version
}
get_bios_release_date() {
	dmidecode -s bios-release-date
}
get_bios_revision() {
	dmidecode -s bios-revision
}
get_bios_firmware_revision() {
	dmidecode -s firmware-revision
}
get_bios_mode() {
	#[ -d /sys/firmware/efi ] && bios_mode="UEFI Mode" || bios_mode="Legacy Mode"
	[ -d /sys/firmware/efi ] && echo "UEFI Mode" || echo "Legacy Mode"
}

# --- Create JSON---
# Clean dim with jq
safe_json() {
    jq -n --arg val "$1" '$val'
}

REPORT_JSON=$(jq -n \
  --arg org "inventory" \
  --arg hn "$(hostname)" \
  --arg iip "$(get_internal_ip)" \
  --arg eip "$(get_external_ip)" \
  --arg ram "$(free -h | awk '/Mem:/ {print $2}')" \
  --arg dsk "$(get_disk_list)" \
  --arg gpu "$(get_gpu)" \
  --arg dst "$DISTRO" \
  --arg ker "$KERNEL" \
  --arg upt "$(uptime -p)" \
  --arg virt "$(get_virt_control)" \
  --arg lastboot "$(get_last_boot)" \
  --arg biosvendor "$(get_bios_vendor)" \
  --arg biosversion "$(get_bios_version)" \
  --arg biosreleasedate "$(get_bios_release_date)" \
  --arg biosrevision "$(get_bios_revision)" \
  --arg biosfirmwarerevision "$(get_bios_firmware_revision)" \
  --arg biosmode "$(get_bios_mode)" \
  '{
    origin: $org,
    hostname: $hn,
    internal_ip: $iip,
    external_ip: $eip,
    ram_total: $ram,
    disk_list: $dsk,
    gpu: $gpu,
    distro: $dst,
    kernel: $ker,
    uptime: $upt,
    virt_control: $virt,
    last_boot: $lastboot,
    bios_vendor: $biosvendor,
    bios_version: $biosversion,
    bios_release_date: $biosreleasedate,
    bios_revision: $biosrevision,
    bios_firmware_revision: $biosfirmwarerevision,
    bios_mode: $biosmode
  }')

echo "$REPORT_JSON"

