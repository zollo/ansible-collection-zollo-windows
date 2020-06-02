#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

ANSIBLE_METADATA = {'status': ['preview'],
                    'supported_by': 'community',
                    'metadata_version': '1.1'}

DOCUMENTATION = r'''
---
module: win_dhcp_info
short_description: Manage Windows Packages
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Windows Package Manager is a comprehensive package manager solution that
    consists of a command line tool and set of services for installing
    applications on Windows 10.
options:
  state:
    description:
      - Setting l(present) will ensure that the package is installed.
      - l(absent) will remove the package if it is installed.
      - l(latest) will
    type: str
    default: all
    choices: [ present, absent, latest ]
  name:
    description:
      - A list of package names, like l(foo), or package specifier with version,
        like l(foo=1.0).
    type: list
'''

EXAMPLES = r'''
- name: Ensure packages are present
  win_winget:
    name:
      - vmware-tools
      - vscode

- name: Ensure VMware Tools is present
  win_winget:
    name: vmware-tools
'''

RETURN = r'''

'''
