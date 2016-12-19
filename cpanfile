requires 'perl', '5.010';

requires 'Mojo::UserAgent';
requires 'Path::Tiny';
requires 'Class::Tiny';
requires 'URI';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Exception';
    requires 'Mock::Quick';
};

on 'develop' => sub {
    requires 'Minilla';
    requires 'Module::Build::Tiny';
};
