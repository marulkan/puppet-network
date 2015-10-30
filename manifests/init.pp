# == Class: network
#
# This module manages Red Hat/Fedora network configuration.
#
# === Parameters:
#
# None
#
# === Actions:
#
# Defines the network service so that other resources can notify it to restart.
#
# === Sample Usage:
#
#   include '::network'
#
# === Authors:
#
# Mike Arnold <mike@razorsedge.org>
#
# === Copyright:
#
# Copyright (C) 2011 Mike Arnold, unless otherwise noted.
#
class network {
  # Only run on RedHat derived systems.
  case $::osfamily {
    'RedHat': { }
    default: {
      fail('This network module only supports RedHat-based systems.')
    }
  }

  service { 'network':
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
  }
} # class network

# == Definition: network_if_base
#
# This definition is private, i.e. it is not intended to be called directly
# by users.  It can be used to write out the following device files:
#  /etc/sysconfig/networking-scripts/ifcfg-eth
#  /etc/sysconfig/networking-scripts/ifcfg-eth:alias
#  /etc/sysconfig/networking-scripts/ifcfg-bond(master)
#
# === Parameters:
#
#   $ensure        - required - up|down
#   $ipaddress     - required
#   $netmask       - required
#   $macaddress    - required
#   $gateway       - optional
#   $bootproto     - optional
#   $userctl       - optional - defaults to false
#   $mtu           - optional
#   $dhcp_hostname - optional
#   $ethtool_opts  - optional
#   $bonding_opts  - optional
#   $isalias       - optional
#   $peerdns       - optional
#   $dns1          - optional
#   $dns2          - optional
#   $domain        - optional
#   $bridge        - optional
#
# === Actions:
#
# Performs 'service network restart' after any changes to the ifcfg file.
#
# === TODO:
#
#   METRIC=
#   HOTPLUG=yes|no
#   WINDOW=
#   SCOPE=
#   SRCADDR=
#   NOZEROCONF=yes
#   PERSISTENT_DHCLIENT=yes|no|1|0
#   DHCPRELEASE=yes|no|1|0
#   DHCLIENT_IGNORE_GATEWAY=yes|no|1|0
#   REORDER_HDR=yes|no
#
# === Authors:
#
# Mike Arnold <mike@razorsedge.org>
#
# === Copyright:
#
# Copyright (C) 2011 Mike Arnold, unless otherwise noted.
#
define network_if_base (
  $ensure,
  $ipaddress,
  $netmask,
  $macaddress,
  $gateway = undef,
  $ipv6address = undef,
  $ipv6gateway = undef,
  $ipv6init = false,
  $ipv6autoconf = false,
  $bootproto = 'none',
  $userctl = false,
  $mtu = undef,
  $dhcp_hostname = undef,
  $ethtool_opts = undef,
  $bonding_opts = undef,
  $isalias = false,
  $peerdns = false,
  $ipv6peerdns = false,
  $dns1 = undef,
  $dns2 = undef,
  $domain = undef,
  $bridge = undef,
  $linkdelay = undef
) {
  # interface static
  $network_if_statics = hiera_hash('network::if::static',undef)
  if $network_if_statics != undef {
    create_resources('network::if::static', $network_if_statics)
  }

  # interface dhcp
  $network_if_dynamics = hiera_hash('network::if::dynamic',undef)
  if $network_if_dynamics != undef {
    create_resources('network::if::dynamic', $network_if_dynamics)
  }

  # interface aliases
  $network_if_aliases = hiera_hash('network::if::alias',undef)
  if $network_if_aliases != undef {
    create_resources('network::if::alias', $network_if_aliases)
  }

  # bond static
  $network_bond_statics = hiera_hash('network::bond::static',undef)
  if $network_bond_statics != undef {
    create_resources('network::bond::static', $network_bond_statics)
  }

  # bond dhcp
  $network_bond_dynamics = hiera_hash('network::bond::dynamic',undef)
  if $network_bond_dynamics != undef {
    create_resources('network::bond::dynamic', $network_bond_dynamics)
  }

  # bond slaves
  $network_bond_slaves = hiera_hash('network::bond::slave',undef)
  if $network_bond_slaves != undef {
    create_resources('network::bond::slave', $network_bond_slaves)
  }

  # bond aliases
  $network_bond_aliases = hiera_hash('network::bond::alias',undef)
  if $network_bond_aliases != undef {
    create_resources('network::bond::alias', $network_bond_aliases)
  }

  # routes
  $network_routes = hiera_hash('network::route',undef)
  if $network_routes != undef {
    create_resources('network::route', $network_routes)
  }

  # Validate our booleans
  validate_bool($userctl)
  validate_bool($isalias)
  validate_bool($peerdns)
  validate_bool($ipv6init)
  validate_bool($ipv6autoconf)
  validate_bool($ipv6peerdns)
  # Validate our regular expressions
  $states = [ '^up$', '^down$' ]
  validate_re($ensure, $states, '$ensure must be either "up" or "down".')

  include '::network'

  $interface = $name

  # Deal with the case where $dns2 is non-empty and $dns1 is empty.
  if $dns2 {
    if !$dns1 {
      $dns1_real = $dns2
      $dns2_real = undef
    } else {
      $dns1_real = $dns1
      $dns2_real = $dns2
    }
  } else {
    $dns1_real = $dns1
    $dns2_real = $dns2
  }

  if $isalias {
    $onparent = $ensure ? {
      'up'    => 'yes',
      'down'  => 'no',
      default => undef,
    }
    $iftemplate = template('network/ifcfg-alias.erb')
  } else {
    $onboot = $ensure ? {
      'up'    => 'yes',
      'down'  => 'no',
      default => undef,
    }
    $iftemplate = template('network/ifcfg-eth.erb')
  }

  file { "ifcfg-${interface}":
    ensure  => 'present',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    path    => "/etc/sysconfig/network-scripts/ifcfg-${interface}",
    content => $iftemplate,
    notify  => Service['network'],
  }
} # define network_if_base
