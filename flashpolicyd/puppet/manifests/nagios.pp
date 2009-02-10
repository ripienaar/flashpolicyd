class flashpolicyd::nagios {
	file {"/usr/local/bin/check_flashpolicyd":
		owner	=> root,
		group	=> root,
		mode	=> 755,
		source	=> "puppet://puppet/flashpolicyd/check_flashpolicyd.rb"
	}
}
