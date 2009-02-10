class flashpolicyd::config {
	file{"/etc/flashpolicy.xml":
		source	=> "puppet://puppet/flashpolicyd/flashpolicy.xml",
		owner	=> root,
		group	=> root,
		mode	=> 644,
		notify  => Service["flashpolicyd"]
	}
}
