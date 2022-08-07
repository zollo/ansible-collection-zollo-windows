#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2021 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: win_domain_info
short_description: Gathers info on Active Directory Domain
author: Joe Zollo (@zollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Manage Active Directory Organizational Units
  - Adds, Removes and Modifies Active Directory Organizational Units
  - Task should be delegated to a Windows Active Directory Domain Controller
options:
  site:
    description:
      - abc
    type: str
    required: true

  discover:
    description:
      - abc
    type: str
    required: true

  filter:
    description:
      - abc
    type: str
    required: true

  identity:
    description:
      - abc
    type: str
    required: true

  service:
    description:
      - abc
    type: str
    required: true

  xyz:
    description:
      - abc
    type: str
    required: true

  domain_username:
    description:
      - The username to use when interacting with AD.
      - If this is not set then the user Ansible used to log in with will be
        used instead when using CredSSP or Kerberos with credential delegation.
    type: str
  domain_password:
    description:
      - The password for I(username).
    type: str
  domain_server:
    description:
      - Specifies the Active Directory Domain Services instance to connect to.
      - Can be in the form of an FQDN or NetBIOS name.
      - If not specified then the value is based on the domain of the computer
        running PowerShell.
    type: str
'''

EXAMPLES = r'''
- name: Ensure OU is present & protected
  community.windows.win_domain_info:
    name: EUC Users
    service:
      - PrimaryDC
      - ADWS

- name: Ensure OU is absent
  community.windows.win_domain_info:
    name: EUC Users
    state: absent

'''

RETURN = r'''
ou:
  description: New/Updated organizational unit parameters
  returned: When l(state=present)
  type: dict
  sample:
    name:
    guid:
    distinguished_name:
    created:
    modified:
    protected:
    display_name:
    description:
    managed_by:
    location:
      city:
      state: 
      street_address:
      postal_code:
      country:
    attributes:
'''
