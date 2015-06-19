package Dancer::Session::Cached;
# ABSTRACT: cache session for a request life-cycle


=head1 SYNOPSIS

In config.yml

    session:       Cached
    session_class: YAML


=head1 DESCRIPTION

Before Dancer v1.3136, each call to the C<session()> was triggering a C<retrieve()> of the
data. Which for some session engine is quite a costly operation. In V1.3136, the behavior was changed such that
the session information is cached upon first C<retrieve()>, thus providing a boost in efficiency.

Unfortunately, there is a catch. If the user calls C<destroy()> on the session object, the engine 
would destroy the underlying data, but the cached version would live on. 

    get '/something' => sub {
        session foo => 'bar';

        session->destroy;

        session 'foo';  # will return 'bar' because it has been cached
    };


For that problem to be observed, one has to try to read from the session after it was C<destroy()>ed. 
Which seems silly, but there are cases where it's a sensible thing to do. Like if one is
to use L<Dancer::Plugin::FlashMessage>:

    get '/logout' => sub {
        session->destroy;
        flash msg => 'Come back soon!';
    };

Because of that, the cached behavior had to be rolled back from the main Dancer code as there is no way for the core code to affect how the session objects implement C<destroy()>. 

And this is where this module enter the picture. It wraps any other session object and makes its C<create()> 
/ C<retrieve> / C<destroy> methods aware of the cache.

=head1 CONFIGURATION PARAMETERS

This module only adds one configuration parameter, C<session_class>, which is the underlying
session engine you want to use. For example, the configuration stanza to enable caching for L<Dancer::Session::YAML> would be

    session:       Cached
    session_class: YAML

=cut

use strict;
use warnings;

use Dancer;

use base 'Dancer::Session::Abstract';

sub new {
    my $self = shift;

    my $inner_class = config->{session_class}
        or raise core_session "config parameter 'session_class' was not set";

    my $engine = Dancer::Engine->build(session => $inner_class, config());

    Role::Tiny->apply_roles_to_object($engine,'Dancer::Session::Cached::Role');

    return $engine;
}

{
package
    Dancer::Session::Cached::Role;

use Role::Tiny;

use Dancer;

my $cached;

hook before => sub { $cached = undef };

around create => sub {
    my($orig,@args) = @_;

    $cached = $orig->(@args);

    Role::Tiny->apply_roles_to_object( $cached, __PACKAGE__  )
        unless Role::Tiny::does_role( $cached, __PACKAGE__ );

    return $cached;
};

around retrieve => sub {
    my($orig,@args) = @_;

    unless ( $cached ) {
        $cached = $orig->(@args) or return;
        Role::Tiny->apply_roles_to_object( $cached, __PACKAGE__ )
            unless Role::Tiny::does_role( $cached, __PACKAGE__ );
    }

    return $cached;
};

around destroy => sub {
    my($orig,@args) = @_;

    $cached = undef;
    $orig->(@args);
    return;
};

}

1;


