class flashpolicyd::service {
	service{"flashpolicyd":
		enable	=> true,
		ensure	=> running,
		require => Class["flashpolicyd::config"]
	}
}
