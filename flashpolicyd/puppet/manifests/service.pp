class flashpolicyd::service {
	file{"/etc/init.d/flashpolicyd":
		owner	=> root,
		group	=> root,
		mode	=> 755,
		source	=> "puppet://puppet/flashpolicyd/flashpolicyd.init",
	}

	file{"/usr/sbin/flashpolicyd":
		owner	=> root,
		group	=> root,
		mode	=> 755,
		source	=> "puppet://puppet/flashpolicyd/flashpolicyd",
	}

	service{"flashpolicyd":
		enable	=> true,
		ensure	=> running,
		require => [ File["/usr/sbin/flashpolicyd"],
                             File["/etc/init.d/flashpolicyd"],
                             File["/etc/flashpolicy.xml"] ]
	}
}
