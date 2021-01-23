#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_computer_info
short_description: Gathers Info on Windows
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Gathers Info on Windows Operating Systems
options: {}
'''

EXAMPLES = r'''
- name: Gather info on local server
  community.windows.win_computer_info:
'''

RETURN = r'''
info:
  description: Computer Info
  returned: success
  type: list
  sample:
'''
