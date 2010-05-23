class flashpolicyd::install {
	File{
		owner	=> root,
		group	=> root,
		mode	=> 755,
	}

	file{"/etc/init.d/flashpolicyd":
		source	=> "puppet://puppet/flashpolicyd/flashpolicyd.init";

	     "/usr/sbin/flashpolicyd":
		source	=> "puppet://puppet/flashpolicyd/flashpolicyd.rb";
	}
}
