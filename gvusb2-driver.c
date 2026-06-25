// SPDX-License-Identifier: GPL-2.0-only OR BSD-3-Clause
/*
 * Copyright (c) 2019 Isaac Lozano <109lozanoi@gmail.com>
 */

#include <linux/module.h>
#include <linux/usb.h>

#include "gvusb2.h"

MODULE_DESCRIPTION("gvusb2 capture driver");
MODULE_AUTHOR("Isaac Lozano <109lozanoi@gmail.com>");
MODULE_LICENSE("Dual BSD/GPL");
MODULE_SOFTDEP("pre: usbtv");

static const struct usb_device_id gvusb2_id_table[] = {
	{ USB_DEVICE(GVUSB2_VENDOR_ID, GVUSB2_PRODUCT_ID) },
	{ }
};
MODULE_DEVICE_TABLE(usb, gvusb2_id_table);

static struct usb_driver gvusb2_video_driver = {
	.name = "gvusb2-video",
	.probe = gvusb2_vid_probe,
	.disconnect = gvusb2_vid_disconnect,
	.id_table = gvusb2_id_table,
};

static struct usb_driver gvusb2_audio_driver = {
	.name = "gvusb2-audio",
	.probe = gvusb2_snd_probe,
	.disconnect = gvusb2_snd_disconnect,
	.id_table = gvusb2_id_table,
};

static int __init gvusb2_module_init(void)
{
	int ret;

	ret = usb_register(&gvusb2_video_driver);
	if (ret)
		return ret;

	ret = usb_register(&gvusb2_audio_driver);
	if (ret) {
		usb_deregister(&gvusb2_video_driver);
		return ret;
	}

	return 0;
}

static void __exit gvusb2_module_exit(void)
{
	usb_deregister(&gvusb2_audio_driver);
	usb_deregister(&gvusb2_video_driver);
}

module_init(gvusb2_module_init);
module_exit(gvusb2_module_exit);
