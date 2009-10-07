class flashpolicyd::config {
	file{"/etc/flashpolicy.xml":
		owner	=> root,
		group	=> root,
		mode	=> 644,
		require	=> Class["flashpolicyd::install"],
		notify  => Class["flashpolicyd::service"]
		source	=> "puppet://puppet/flashpolicyd/flashpolicy.xml",
	}
}
