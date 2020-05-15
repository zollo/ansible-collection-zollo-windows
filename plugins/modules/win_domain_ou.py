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
module: win_domain_ou
short_description: Manage Active Directory Organizational Units
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Manage Active Directory Organizational Units
  - Adds, Removes and Modifies DNS Zones, Forward, Stub & Reverse
  - Task should be delegated to a Windows Active Directory Domain Controller
options:
  name:
    description:
      - 
    type: str
  protected:
    description:
      - 
    type: bool
    default: forest
  path:
    description:
      - 
    type: str
  state:
    description:
      - 
    type: str
    default: present
    choices: [ present, absent ]
author:
- Joseph Zollo (@joezollo)
'''

EXAMPLES = r'''
- name: Ensure organizational is present
  win_domain_ou:
    name: users
    path: DC=euc,DC=vmware,DC=lan
    state: present
    protected: true

- name: Ensure organizational unit is absent
  win_domain_ou:
    name: users
    path: DC=euc,DC=vmware,DC=lan
    state: present
    protected: true
'''

RETURN = r'''
ou:
  description: New/Updated organizational unit parameters
  returned: When l(state=present)
  type: dict
  sample:
    name: 
    type: 
    dynamic_update: 
    state: 
    replication: 
    dns_servers: 
'''