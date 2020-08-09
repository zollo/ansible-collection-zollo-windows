#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_dns_info
short_description: Gathers Info on Windows Server DNS Objects
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Gathers Info on Windows Server DNS Zones
  - Task should be delegated to a Windows DNS Server
options:
  type:
    description:
      - Specifies the type of DNS object to retreive
      - Specifying l(all) will retrieve the zone object and all matched records
        based on l(record_type) and l(record_name)
      - Specifying l(zone) will retrieve just the matched zone record based
        on l(zone_type) and l(zone_name)
      - Specifying l(record) will retreive just the matched records based on
        l(record_type) and l(record_name)
    type: str
    default: all
    choices: [ zone, record, all ]
  zone_name:
    description:
      - Specifies the DNS zone name to query for.
      - Omitting this parameter will retreive all zones.
    type: str
  zone_type:
    description:
      - Specifies the DNS zone type to query for.
      - Omitting this parameter will retreive all zone types.
    type: str
    choices: [ primary, secondary, stub, forwarder ]
  record_type:
    description:
      - Specifies the DNS record type to query for.
      - Omitting this parameter will retreive all types of records.
    type: str
    choices: [ A, AAAA, MX, CNAME, PTR, NS, TXT ]
  record_name:
    description:
      - Specifies the DNS record name to query for.
    type: str
  filter_ad:
    description:
      - When set to l(true), Active Directory related records
        are filtered out. These are mostly records related to
        LDAP and kerberos functions. Nodes that start with l(_msdcs),
        l(_sites), l(_tcp), l(_udp), l(DomainDnsZones), l(ForestDnsZones).
    type: bool
    default: true
'''

EXAMPLES = r'''
- name: Gather info on all DNS records in a single zone
  community.windows.win_dns_info:
    type: zone
    zone_name: henretty.euc.vmware.com

- name: Gather info on all primary DNS zones
  community.windows.win_dns_info:
    type: zone
    zone_type: primary

- name: Gather info on all primary DNS zones and their records
  community.windows.win_dns_info:
    type: all
    zone_type: primary

- name: Gather info on all DNS zones and records
  community.windows.win_dns_info:
    type: all

- name: Gather info on all A records in the zone chall.euc.vmware.com
  community.windows.win_dns_info:
    type: all
    zone_name: chall.euc.vmware.com
    record_type: A

- name: Gather info on DNS zone sde.vmware.com
  community.windows.win_dns_info:
    type: zone
    zone_name: sde.vmware.com

- name: Gather info on a single DNS record
  community.windows.win_dns_info:
    type: record
    zone_name: sde.vmware.com
    record_name: shri
'''

RETURN = r'''
zones:
  description: DNS zone(s) with record(s)
  returned: When l(type=zone) or l(type=all)
  type: dict
  sample:
    - name: rds.vmware.com
      type: primary
      dynamic_update: secure
      replication: forest
      nameservers:
        - 10.125.100.50
        - 10.125.100.51
      dns_records:
        - name: jwilliams
          fqdn: jwilliams.rnd.vmware.com
          type: A
          data: 172.16.200.100
          ttl: 3600
        - name: vmcneeley
          fqdn: vmcneeley.rnd.vmware.com
          type: MX
          data:
            mail_exchange: mail.rnd.vmware.com
            priority: 0
          ttl: 900
    - name: sde.vmware.com
      type: primary
      dynamic_update: secure
      replication: forest
      nameservers:
        - 10.125.107.50
        - 10.125.108.50
      dns_records:
        - name: chall
          fqdn: chall.sde.vmware.com
          type: CNAME
          data: chall-prod.sde.vmware.com
          ttl: 3600

records:
  description: DNS record(s)
  returned: When l(type=record) or l(type=all)
  type: dict
  sample:
    - name: asedevie
      fqdn: asedevie.euc.vmware.com
      type: A
      data: 10.100.100.85
      ttl: 600
    - name: paynem
      fqdn: paynem.euc.vmware.com
      type: MX
      data:
        mail_exchange: tech-proposals.euc.vmware.com
        priority: 0
      ttl: 900
'''