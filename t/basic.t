use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 6;

{
    package MyApp;

    use Dancer;
    use Dancer::Session::Cached;

    set session_class => 'VerySimple';
    set session => 'Cached';

    get '/' => sub {
        session 'x' => 'blah';

        return join '',  session( 'x' ), session( 'x' );
    };

    get '/retrieve' => sub {
        return join '', map { session($_) }  ('x')x3;
    };

    get '/session' => sub {
        return join '', %{ session() };
    };

    get '/destroy' => sub {
        $DB::single = 1;
        
        session->destroy;
        $::ME = 1;
        return join '', %{ session() };
    };

}

use Dancer::Test;

response_content_like '/' => qr/blahblah/;

is $::retrieve => undef, 'only creation, no retrieve';

response_content_like '/retrieve' => qr/(?:blah){3}/;

is $::retrieve => 1, 'only once';

response_content_like '/' => qr/blahblah/;

is $::retrieve => 2, 'only retrieve';

response_content_like '/session' => qr/xblah/;

response_content_unlike '/destroy' => qr/xblah/;

response_content_unlike '/session' => qr/xblah/;
