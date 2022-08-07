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
  state:
    description:
      - Specifies the desired state of the OU.
      - When l(state=present) the module will attempt to create the specified
        OU if it does not already exist.
      - When l(state=absent), the module will remove the specified OU and all
        child OU's recursively.
    type: str
    default: present
    choices: [ present, absent ]
  name:
    description:
      - The name of the Organizational Unit
    type: str
    required: true
  protected:
    description:
      - Indicates whether to prevent the object from being deleted. When this
        l(protected=true), you cannot delete the corresponding object without
        changing the value of the property.
    type: bool
    default: false
  path:
    description:
      - Specifies the X.500 path of the OU or container where the new object is
        created.
      - If not defined, new OU objects will be created at the base distinguished
        name for the domain. For test.domain.com, a new OU would be created at 
        l(OU=New,DN=test,DN=domain,DN=com).
    type: str
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
  managed_by:
    description:
      - Specifies the user or group that manages the object by providing one of the
        following property values - distinguished name, objectGUID, objectSid (security
        identifier) or sAMAccountName (SAM account name).
    type: str
  display_name:
    description:
      - Specifies the display name of the object. This parameter sets the DisplayName
        property of the OU object. The LDAP display name (ldapDisplayName) for this
        property is displayName.
    type: str
  description:
    description:
      - Specifies a description of the object. This parameter sets the
        value of the Description property for the OU object. The LDAP
        display name (ldapDisplayName) for this property is description.
    type: str
  location:
    type: dict
    description:
      - Defines specific LDAP based properties for the organizational unit.
    suboptions:
      state:
        description:
          - Specifies a state or province. This parameter sets the State property
            of an OU object. The LDAP display name (ldapDisplayName) of this property
            is st.
        type: str
      city:
        description:
          - Specifies the town or city. This parameter sets the City property of an OU object.
            The Lightweight Directory Access Protocol (LDAP) display name (ldapDisplayName)
            of this property is l.
        type: str
      street_address:
        description:
          - Specifies a street address. This parameter sets the StreetAddress property
            of an OU object. The LDAP display name (ldapDisplayName) of this property
            is street.
        type: str
      postal_code:
        description:
          - Specifies the postal code or zip code. This parameter sets
            the PostalCode property of an OU object. The LDAP display
            name (ldapDisplayName) of this property is postalCode.
        type: int
      country:
        description:
          - Specifies the country or region code. This parameter sets the Country property
            of an OU object. The LDAP display name (ldapDisplayName) of this property is c.
          - This must be the two letter country code, examples - US (United States),
            BM (Bermuda), MX (Mexico), FR (France).
        type: str
  attributes:
    type: dict
    description:
      - Defines specific LDAP properties for the organizational unit.
      - Provides enables a one-to-one mapping to LDAP properties (keys) 
        to values.
'''

EXAMPLES = r'''
- name: Ensure OU is present & protected
  community.windows.win_domain_ou:
    name: EUC Users
    protected: true
    attributes:
      

- name: Ensure OU is absent
  community.windows.win_domain_ou:
    name: EUC Users
    state: absent

- name: Ensure OU is present with specific properties
  community.windows.win_domain_ou:
    name: users
    protected: true
    location:
      city: Sandy Springs
      state: Georgia
      street_address: 1155 Perimeter Center West
      country: US
      postal_code: 30189
    description: EUC Business Unit
    attributes:
      extensionName: Jenny
      url:
        - ansible.com
        - https://ansible.com

- name: Ensure OU updated with new properties
  community.windows.win_domain_ou:
    name: ws1users
    path: "OU=users,DC=euc,DC=vmware,DC=lan"
    location:
      city: Sandy Springs
      state: Georgia
      street_address: 1155 Perimeter Center West
      country: US
      postal_code: 30189
    other_attributes:
      facsimileTelephoneNumber: 404-555-5555
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
