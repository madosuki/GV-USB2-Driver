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

static int gvusb2_probe(struct usb_interface *intf,
	const struct usb_device_id *id)
{
	int ret;

	ret = gvusb2_vid_probe(intf, id);
	if (ret != -ENODEV)
		return ret;

	return gvusb2_snd_probe(intf, id);
}

static void gvusb2_disconnect(struct usb_interface *intf)
{
	enum gvusb2_interface_type *type = usb_get_intfdata(intf);

	if (!type)
		return;

	switch (*type) {
	case GVUSB2_INTF_VIDEO:
		gvusb2_vid_disconnect(intf);
		break;
	case GVUSB2_INTF_SOUND:
		gvusb2_snd_disconnect(intf);
		break;
	default:
		usb_set_intfdata(intf, NULL);
		break;
	}
}

static struct usb_driver gvusb2_usb_driver = {
	.name = "gvusb2",
	.probe = gvusb2_probe,
	.disconnect = gvusb2_disconnect,
	.id_table = gvusb2_id_table,
};

module_usb_driver(gvusb2_usb_driver);
