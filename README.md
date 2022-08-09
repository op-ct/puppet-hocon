# HOCON file

#### Table of Contents


<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
* [Module Description](#module-description)
* [Setup](#setup)
  * [Beginning with hocon](#beginning-with-hocon)
* [Usage](#usage)
  * [Individual settings](#individual-settings)
  * [Nested settings](#nested-settings)
  * [Deleting settings](#deleting-settings)
* [Reference](#reference)
* [Development](#development)

<!-- vim-markdown-toc -->

## Overview

This module provides resource types to manage settings in
[HOCON-style](https://github.com/lightbend/config/blob/master/HOCON.md)
configuration files.

## Module Description

The hocon module adds a resource type so that you can use Puppet to manage
settings in HOCON configuration files. If you would like to manage Puppet's
auth.conf that is in the HOCON format, see the
[puppet/puppet_authorization](https://github.com/voxpupuli/puppet-puppet_authorization)
module.

## Setup

### Beginning with hocon

To manage a HOCON file, add the resource type `hocon_setting` to a class.

## Usage

### Individual settings

Manage individual settings in HOCON files by adding the `hocon_setting`
resource type to a class. For example:

```puppet
hocon_setting { "sample setting":
  ensure  => present,
  path    => '/tmp/foo.conf',
  setting => 'foosetting',
  value   => 'FOO!',
}
```

### Nested settings

To control a setting nested within a map contained at another setting, provide
the path to that setting under the "setting" parameter, with each level
separated by a ".". So to manage `barsetting` in the following map:

```puppet
foo : {
    bar : {
        barsetting : "FOO!"
    }
}
```

You would put the following in your manifest:

```puppet
hocon_setting {'sample nested setting':
  ensure  => present,
  path    => '/tmp/foo.conf',
  setting => 'foo.bar.barsetting',
  value   => 'BAR!',
}
```

You can also set maps like so:

```puppet
hocon_setting { 'sample map setting':
  ensure  => present,
  path    => '/tmp/foo.conf',
  setting => 'hash_setting',
  value   => { 'a' => 'b' },
}
```

### Deleting settings

To delete a top level key, you will need to specify both the key name and the
type of key.

```puppet
hocon_setting { 'delete top key':
  ensure  => absent,
  path    => '/tmp/foo.conf',
  setting => 'array_key',
  type    => 'array',
```

## Reference

See [REFERENCE.md](./REFERENCE.md).

## Development

This module is maintained by [Vox Pupuli](https://voxpupuli.org/). Vox Pupuli
welcomes new contributions to this module, especially those that include
documentation and rspec tests. We are happy to provide guidance if necessary.

Please see [CONTRIBUTING](.github/CONTRIBUTING.md) for more details.

Please log tickets and issues on github.
