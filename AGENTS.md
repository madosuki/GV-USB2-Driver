# Repository Notes

## Next Task

- If `lsusb` still hangs after unplugging the GV-USB2, keep the GV-USB2 chip-specific register/init paths intact and focus next on EasyCap/usbtv-style disconnect lifetime handling:
  - audit video/audio URB shutdown ordering in `gvusb2-vid.c` and `gvusb2-snd.c`
  - ensure `disconnected` / `running = false` is visible before `usb_kill_urb()`
  - confirm all URB completion paths stop resubmitting before resources are freed
  - check whether ALSA `snd_card_free_when_closed()` can delay USB ref release
  - verify `usb_get_dev()` / `usb_put_dev()` balance after physical unplug

## Current Experiment

- `gvusb2-driver.c` now registers separate USB drivers for video and audio interfaces in the same `gvusb2.ko`.
- The GV-USB2-specific chip initialization, I2C/TW9910 setup, V4L2 logic, audio ADC reset, and isochronous data paths are intentionally left unchanged.
