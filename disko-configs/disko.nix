{
  disko.devices = {
    disk = {
      # Название диска внутри конфига (может быть любым)
      main = {
        # Укажите правильный путь к вашему жесткому диску или SSD
        # (например: /dev/sda, /dev/nvme0n1)
        device = "/dev/sda"; 
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            # 1. Загрузочный раздел UEFI
            ESP = {
              priority = 1;
              name = "ESP";
              size = "512M";
              type = "EF00"; # Тип раздела для EFI в GPT
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            
            # 2. Раздел подкачки (Swap)
            swap = {
              size = "8G"; # Укажите нужный размер оперативной памяти
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = true; # Использовать для гибернации (по желанию)
              };
            };

            # 3. Корневой раздел (Root)
            root = {
              size = "100%"; # Занять всё оставшееся пространство
              content = {
                type = "filesystem";
                format = "btrfs";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}

