use Module::Build;
Module::Build->new(
    module_name => 'Net::Symon::NetBrite',
    license => 'perl',
    requires => {
        perl => '5.6.1',
        'Digest::CRC' => '0.18',
        'IO::Socket::INET' => '1.31',
    },
)->create_build_script();
