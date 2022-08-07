# Ansible Collection (WIP/Non-Production)

## zollo.windows

This repo hosts the `zollo.windows` Ansible Collection.

The collection includes a variety of Ansible content to help automate the management of Windows Server.

## Included Content

Click on the name of a plugin or module to view that content's documentation:

- **Modules**:
  - win_dhcp_lease
  - win_dhcp_info
  - win_dns_zone
  - win_dns_info
  - win_domain_ou

- **Modules: WIP**:
  - win_dhcp_scope
  - win_ca_cert
  - win_msi_info
  - win_gp_info
  - win_ntp_client
  - win_domain_info

## Installation and Usage

### Installing the Collection from Ansible Galaxy

Before using this collection, you need to install it with the Ansible Galaxy CLI:

    ```yaml
    ansible-galaxy collection install zollo.windows
    ```

You can also include it in a `requirements.yml` file and install it via `ansible-galaxy collection install -r requirements.yml`, using the format:

    ```yaml
    ---
    collections:
      - name: zollo.windows
        version: 0.1.0
    ```

### Using modules from the Windows Server Collection in your playbooks

You can either call modules by their Fully Qualified Collection Namespace (FQCN), like `zollo.windows.win_dhcp_lease`, or you can call modules by their short name if you list the `zollo.windows` collection in the playbook's `collections`, like so:

    ```yaml
    ---
    - hosts: localhost
      gather_facts: false
      connection: local
      collections:
        - zollo.windows
      tasks:
        - name: Ensure the DHCP scope exists
          win_dhcp_scope:
            name: test

        - name: Gather facts on a specific DHCP scope
          win_dhcp_info:
            name: 192.168.30.0-vlan0
            type: scope
    ```

For documentation on how to use individual modules and other content included in this collection, please see the links in the 'Included content' section earlier in this README.

## Testing and Development

If you want to develop new content for this collection or improve what's already here, the easiest way to work on the collection is to clone it into one of the configured [`COLLECTIONS_PATHS`](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#collections-paths), and work on it there.

### Testing with `ansible-test`

The `tests` directory contains configuration for running sanity and integration tests using [`ansible-test`](https://docs.ansible.com/ansible/latest/dev_guide/testing_integration.html).

You can run the collection's test suites with the commands:

    ```yaml
    ansible-test sanity --docker -v --color
    ansible-test integration --docker -v --color
    ```

## Publishing New Versions

The current process for publishing new versions of the DNS/DHCP Collection is manual, and requires a user who has access to the `zollo.windows` namespace on Ansible Galaxy to publish the build artifact.

  1. Ensure `CHANGELOG.md` contains all the latest changes.
  2. Update `galaxy.yml` and this README's `requirements.yml` example with the new `version` for the collection.
  3. Tag the version in Git and push to GitHub.
  4. Run the following commands to build and release the new version on Galaxy:

    ```yaml
    ansible-galaxy collection build
    ansible-galaxy collection publish ./zollo-windows-$VERSION_HERE.tar.gz
    ```

After the version is published, verify it exists on the [Windows Server Collection Galaxy page](https://galaxy.ansible.com/).

## More Information

N/A

## License

GNU General Public License v3.0 or later

See LICENCE to see the full text.
