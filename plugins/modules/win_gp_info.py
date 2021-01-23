#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---

short_description: Gathers Info on Windows Server Group Policy Objects
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Manage Active Directory Organizational Units
  - Adds, Removes and Modifies Active Directory Organizational Units
  - Task should be delegated to a Windows Active Directory Domain Controller
options:
  guid:
    description:
      - Specifies the GPO to retrieve by its globally unique identifier (GUID). 
        The GUID uniquely identifies the GPO.
    type: str
  name:
    description:
      - Display name of the group policy object.
    type: str
  domain:
    description:
      - Display name of the group policy object.
    type: str
  server:
    description:
      - Display name of the group policy object.
    type: str
'''

EXAMPLES = r'''
- name: Gather info on all GP objects
  community.windows.win_gp_info:

- name: Gather info on all GP objects
  community.windows.win_gp_info:
'''

RETURN = r'''
gpo:
  - id: 
    display_name: 
    path: dict
'''
