#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_msi_info
short_description: Gathers Info on MSI Installer Packages
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Gathers Info on MSI Installer Packages
options:
  path:
    description:
      - Specifies the path to a valid MSI file
    type: str
    required: true
'''

EXAMPLES = r'''
- name: Gather info on installation file
  community.windows.win_msi_info:
    path: D:\Downloads\WorkspaceONE_UEM_20.20.msi

- name: Gather info on installation file
  community.windows.win_msi_info:
    path: E:\Downloads\WorkspaceONE_Intelligence.msi
'''

RETURN = r'''
properties:
  description: MSI Database Properties
  returned: When successful
  type: dict
  sample:
    ARPPRODUCTICON: Product_black.ico
    DESKTOP_DEFAULT_PORT: 6516
    SSL_CERTIFICATE_OPTION: "generate"
    SET_TRUSTED_HOSTS: "true"
'''