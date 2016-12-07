# Manages the activation of tuned
#
# @param use_sysctl
#     This is the custom sysctl configuration file.  Set to false to
#     use only the ktune settings.
# @param use_sysctl_post
#     This is the ktune sysctl file.  Any settings in this file will be applied
#     after custom settings, overriding them.  Comment this out to not use ktune
#     settings.
# @param io_scheduler
#     This is the I/O scheduler ktune will use.  This will *not* override
#     anything explicitly set on the kernel command line, nor will it change
#     the scheduler for any block device that is using a non-default scheduler
#     when ktune starts.  You should probably leave this on "deadline", but
#     "as", "cfq", and "noop" are also legal values.
# @param elevator_tune_devs
#     These are the devices, that should be tuned with the ELEVATOR
#
# The following options only affect 'tuned'
# @param tuning_interval
#     The number of seconds between tuning runs.
# @param diskmonitor_enable
#     Enable the disk monitoring plugin.
# @param disktuning_enable
#     Enable the disk tuning plugin.
# @param disktuning_hdparm
#     Use 'hdparm' for disk tuning.
# @param disktuning_alpm
#     Use 'ALPM' when disk tuning.
# @param netmonitor_enable
#     Enable the network monitoring plugin.
# @param nettuning_enable
#     Enable the network tuning plugin.
# @param cpumonitor_enable
#     Enable the CPU monitoring plugin.
# @param cputuning_enable
#     Enable the CPU tuning plugin.
#
class tuned (
  Enum['deadline','as','cfq','noop'] $io_scheduler = 'deadline',
  Array[String] $elevator_tune_devs = ['hd','sd','cciss'],
  Boolean $use_sysctl               = true,
  Boolean $use_sysctl_post          = false,
  Integer $tuning_interval          = 10,
  Boolean $diskmonitor_enable       = true,
  Boolean $disktuning_enable        = true,
  Boolean $disktuning_hdparm        = true,
  Boolean $disktuning_alpm          = true,
  Boolean $netmonitor_enable        = true,
  Boolean $nettuning_enable         = true,
  Boolean $cpumonitor_enable        = true,
  Boolean $cputuning_enable         = true
) {

  $ktune_name = 'tuned'

  file { '/etc/tuned.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('tuned/etc/tuned.conf.erb'),
    notify  => Service[$ktune_name]
  }

  file { '/etc/sysconfig/ktune':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('tuned/etc/sysconfig/ktune.erb')
  }

  file { '/etc/sysctl.ktune':
    ensure => 'present',
    owner  => 'root',
    group  => 'root',
    mode   => '0640'
  }

  package { $ktune_name:
    ensure => 'latest'
  }

  service { $ktune_name:
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [
      Package[$ktune_name],
      File['/etc/sysconfig/ktune']
    ]
  }
}
