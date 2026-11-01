on run argv
    set vmName to item 1 of argv
    set diskFile to POSIX file (item 2 of argv)
    set seedFile to POSIX file (item 3 of argv)
    tell application "UTM"
        if exists (virtual machine named vmName) then error "A VM with this name already exists. Choose a fresh name."
        set newVM to make new virtual machine with properties {backend:qemu, configuration:{name:vmName, architecture:"aarch64", memory:4096, cpu cores:2, hypervisor:true, uefi:true, drives:{{source:diskFile, interface:VirtIO}, {removable:true, source:seedFile, interface:USB}}, network interfaces:{{mode:shared, hardware:"virtio-net-pci", isolate from host:false}}}}
        set vmID to id of newVM
        start newVM
        return vmID
    end tell
end run
