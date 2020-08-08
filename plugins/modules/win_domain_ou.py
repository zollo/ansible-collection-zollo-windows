#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_domain_ou
short_description: Manage Active Directory Organizational Units
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Manage Active Directory Organizational Units
  - Adds, Removes and Modifies Active Directory Organizational Units
  - Task should be delegated to a Windows Active Directory Domain Controller
options:
  name:
    description:
      - The name of the Organizational Unit
    type: str
  protected:
    description:
      - Indicates whether to prevent the object from being deleted.
    type: bool
    default: forest
  path:
    description:
      - 
    type: str
  state:
    description:
      - Specifies the desired state of the OU.
      - When l(state=present) the module will attempt to create the specified
        OU if it does not already exist.
      - When l(state=absent), the module will remove the specified OU.
      - When l(state=absent) and l(recursive=true), the module will remove all
        the OU and all child OU's.
    type: str
    default: present
    choices: [ present, absent ]
  recursive:
    description:
      - Removes the OU and any child items it contains.
      - You must specify this parameter to remove an OU that is not empty.
    type: bool
    default: false
  properties:
    description:
      - Placeholder
    type: bool
    default: false
'''

EXAMPLES = r'''
- name: Ensure organizational unit is present
  community.windows.win_domain_ou:
    name: superusers
    path: DC=euc,DC=vmware,DC=lan
    state: present
    protected: true

- name: Ensure organizational unit is absent
  community.windows.win_domain_ou:
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
    path:
    protected
    properties:
      display_name:
      description:
      city:
      street_address:
      postal_code:
      country:
      managed_by:
'''