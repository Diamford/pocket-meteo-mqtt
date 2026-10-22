
{ ... }:

{
  environment.systemPackages = with pkgs; [mosquitto];

	services.mosquitto = {
		enable = true;
		persistence = true;

		listeners = [
			{
				port = 1883;

				users = {
					station01 = {
						passwordFile = "/var/lib/pocketmeteo/secrets/station01";
						acl = [ "write pocketmeteo/station01/data" ];
					};

					station02 = {
						passwordFile = "/var/lib/pocketmeteo/secrets/station02";
						acl = [ "write pocketmeteo/station02/data" ];
					};

					station03 = {
						passwordFile = "/var/lib/pocketmeteo/secrets/station03";
						acl = [ "write pocketmeteo/station03/data" ];
					};

					station04 = {
						passwordFile = "/var/lib/pocketmeteo/secrets/station04";
						acl = [ "write pocketmeteo/station04/data" ];
					};

					station05 = {
						passwordFile = "/var/lib/pocketmeteo/secrets/station05";
						acl = [ "write pocketmeteo/station05/data" ];
					};

					collector = {
						passwordFile = "/var/lib/pocketmeteo/secrets/collector";
						acl = [ "read pocketmeteo/+/data" ];
					};
				};
			}
		];
	};

	networking.firewall.allowedTCPPorts = [ 1883 ];

	environment.systemPackages = [ ];
}

