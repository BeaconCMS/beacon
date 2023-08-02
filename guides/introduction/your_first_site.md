# Your First Site

In this guide we'll walk trough all the steps necessary to have a functioning site with components, styles, and a contact form to demonstrate how Beacon works.

It's required that you have a working Phoenix LiveView with Beacon and Beacon LiveAdmin installed and configured correctly, please follow the [Beacon installation guide](https://github.com/BeaconCMS/beacon/blob/main/guides/introduction/installation.md) and [Beacon LiveAdmin installation guide](https://github.com/BeaconCMS/beacon_live_admin/blob/main/guides/introduction/installation.md) if you're starting from stratch.

## Generating the site

Each site requires some minimal configuratin to run in your application, lets use the built-in `beacon.install` generator to get started quickly. In the root of your application, execute:

```
mix beacon.install --site my_site
```

You can use whatever name you like as long as you remember to change it in the following steps.

