FileView {
  path: "/sys/class/backlight/intel_backlight/actual_brightness"  
  
  /*
    ls /sys/class/backlight/intel_backlight/                                                                     ✔ 
actual_brightness  brightness         max_brightness     scale              type                                
bl_power           device@            power/             subsystem@         uevent 


*/
  watchChanges: true
  onFileChanged: this.reload()
  onLoaded: {
      root.brightness = text();
  }
}