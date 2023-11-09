#!/bin/sh

#variables
min_version="42962"
min_version_long="7.1.1 42962"

patch_bios="40B010: 39"
nas_product=$(cat /proc/sys/kernel/syno_hw_version)
unpacker="https://raw.githubusercontent.com/K4L0dev/Synology_Archive_Extractor/main/sae.py"

declare -A hw_version_list=(
    ["DS1515+"]="https://global.synologydownload.com/download/DSM/release/7.1.1/42962-1/DSM_DS1515+_42962.pat"
    ["DS1815+"]="https://global.synologydownload.com/download/DSM/release/7.1.1/42962-1/DSM_DS1815+_42962.pat"
    ["RS815+"]="https://global.synologydownload.com/download/DSM/release/7.1.1/42962-1/DSM_RS815+_42962.pat"
    ["RS815RP+"]="https://global.synologydownload.com/download/DSM/release/7.1.1/42962-1/DSM_RS815RP+_42962.pat"
)

declare -A hw_update_list=(
    ["synology_avoton_1515+"]="synology_avoton_1517+"
    ["synology_avoton_1815+"]="synology_avoton_1817+"
    ["synology_avoton_rs815+"]="synology_avoton_rs818+"
    ["synology_avoton_rs815rp+"]="synology_avoton_rs818rp+"
)

declare -A hw_update_list2=(
	["DS1515+"]="DS1517+"
	["DS1815+"]="DS1817+"
	["RS815+"]="RS818+"
	["RS815RP+"]="RS818RP+"
)

check_device() {
    local ver="$1"
    for i in "${!hw_version_list[@]}"; do
        [[ "$ver" == *"$i"* ]] && return 0
    done ||  return 1

}

download_dsm() {
	echo "Download the necessary files."
    local key="$1"
	
	for i2 in "${!hw_update_list2[@]}"; do	
	    [[ "$key" == *"$i2"* ]] &&	{
		newmodel=${hw_update_list2[$i2]}
		wget -q --show-progress -N -P ./tmp https://raw.githubusercontent.com/prt1999/Synology_model_upgrade/main/task/$newmodel.sql
        wget -q --show-progress -N -P ./tmp https://raw.githubusercontent.com/prt1999/Synology_model_upgrade/main/task/disableBD.sql
		}
	done	
		
	for i in "${!hw_version_list[@]}"; do
	    [[ "$key" == *"$i"* ]] && {
		wget -q --show-progress -N -P ./tmp ${hw_version_list[$i]}
		wget -q --show-progress -N -P ./tmp $unpacker
		filename=$(basename "${hw_version_list[$i]}")
		echo "Unpack DSM: $filename"
		python ./tmp/sae.py -k SYSTEM -a ./tmp/$filename -d ./tmp
		}
	done 
}

mod_bios() {
	echo "Backup bios.ROM to bios.ROM.original"
	cp ./tmp/bios.ROM ./tmp/bios.ROM.original
	echo "Patch bios.ROM"
	echo "$patch_bios" | xxd -r - ./tmp/bios.ROM
	echo "Upgrade BIOS"
	./tmp/updater -b ./tmp/.
}

mod_model() {
	source "/etc.defaults/synoinfo.conf"
	dsm_model="$unique"
    dsm_model2="$upnpmodelname"
	
	for i in "${!hw_update_list[@]}"; do	
	    [[ "$dsm_model" == *"$i"* ]] &&	{
		echo "Change synoinfo.conf in $dsm_model to ${hw_update_list[$dsm_model]}"
		sed -i "s/unique=\"$dsm_model\"/unique=\"${hw_update_list[$dsm_model]}\"/g" /etc/synoinfo.conf
		sed -i "s/unique=\"$dsm_model\"/unique=\"${hw_update_list[$dsm_model]}\"/g" /etc.defaults/synoinfo.conf
		}
	done

	for i2 in "${!hw_update_list2[@]}"; do	
	    [[ "$dsm_model2" == *"$i2"* ]] &&	{
		newmodel=${hw_update_list2[$dsm_model2]}
		echo "Change synoinfo.conf in $dsm_model2 to ${hw_update_list2[$dsm_model2]}"
		sed -i "s/upnpmodelname=\"$dsm_model2\"/upnpmodelname=\"${hw_update_list2[$dsm_model2]}\"/g" /etc/synoinfo.conf
		sed -i "s/upnpmodelname=\"$dsm_model2\"/upnpmodelname=\"${hw_update_list2[$dsm_model2]}\"/g" /etc.defaults/synoinfo.conf
		}
	done	
}

mod_script() {
    echo ""
	echo "Create Task Schedulers"
	source "/etc.defaults/synoinfo.conf"
    newmodel="$upnpmodelname"
	sqlite3 /usr/syno/etc/esynoscheduler/esynoscheduler.db < ./tmp/$newmodel.sql
	sqlite3 /usr/syno/etc/esynoscheduler/esynoscheduler.db < ./tmp/disableBD.sql
}

#main()
echo "----------------------------------------"
echo "Synology Avoton model upgrade v1.0 - pRT"
echo "----------------------------------------"
echo ""

#check root user
if (( $EUID != 0 )); then
    echo "Please run as root"
    exit 1
fi

#check NAS product
if ! check_device "$nas_product" ; then
	echo -e "Check NAS device : \e[31mFAILED\e[0m"
	echo    "  Not support your NAS device: $nas_product"
	exit 1
fi

echo -e "Check NAS device : \e[32mOK\e[0m"
echo    "  Found: $nas_product"

#check running DSM version
source "/etc/VERSION"
dsm_version="$buildnumber"
dsm_version_long="$productversion $buildnumber-$smallfixnumber"
if [[ ! "$dsm_version" ]] ; then
    echo "  Something went wrong. Could not fetch DSM version"
    exit 1
fi

if [ "$min_version" -gt  "$dsm_version" ] ; then
    echo -e "Check running DSM version: \e[31mFAILED\e[0m"
    echo "  You ($dsm_version_long) DSM version is old."
    echo "  Please update your DSM build to: ($min_version_long)"
    exit 1
fi

echo -e "Check running DSM version: \e[32mOK\e[0m"
echo    "  Found: ($dsm_version_long)"

download_dsm "$nas_product"
echo ""
mod_bios
echo ""
mod_model
echo ""
mod_script

echo ""
echo "Done." 
echo ""
echo "Then manually update to $newmodel DSM 7.2.x from the web interface."
