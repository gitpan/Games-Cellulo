package Games::Cellulo::Game;
$Games::Cellulo::Game::VERSION = '0.2_01';
use strict;
use warnings FATAL => 'all';
use Games::Cellulo::Game::Screen;
use Time::HiRes;
use Games::Cellulo::Game::Particle;

use Moo;
use MooX::Options;

has screen => ( is => 'lazy', handles => [qw/ grid /] );

option sleep_time => (
    is => 'ro',
    format => 's',
    required => 0,
    doc => 'time to sleep between frames',
    default => sub { .03 },
);
option num_particles => (
    is => 'ro',
    format => 'i',
    default => sub { 500 },
    doc => "number of onscreen particles",
);

option meld => (
    is => 'ro',
    doc => 'particles should turn in to each other when stuck'
);

has screen_args => ( 
    is => 'ro',
    default => sub { +{} },
);

has particles => ( 
    is => 'rw',
    default => sub { [] },
);
sub _rand_dir {
    int( rand(3) ) - 1;
}
sub _build_screen {
    Games::Cellulo::Game::Screen->new( shift->screen_args )
}

sub randx {
    my $self = shift;
    my $cols = $self->screen->cols;
    int( rand( $cols )  );
}

sub randy {
    my $self = shift;
    my $rows = $self->screen->rows;
    int( rand( $rows )  );

}

sub init {
    my $self = shift;
    my $rows = $self->screen->rows;
    my $cols = $self->screen->cols;
    $self->screen->clrscr;
    my $grid = $self->screen->grid;
    my @particles;
    for ( 1 .. $self->num_particles ) {
        my $randy = $self->randy;
        my $randx = $self->randx;
        next if $grid->[$randy][$randx];
        $grid->[$randy][$randx] = Games::Cellulo::Game::Particle->new(
            rows => $rows,
            cols => $cols,
            x    => $randx,
            y    => $randy,
            type => int( rand(4) + 1 ),
        );
        push( @particles, $grid->[$randy][$randx] );
    }
    $self->particles( \@particles );
}
my $_moves = 0;
sub moves{ $_moves }
sub play {
    my $self = shift;
    my $_scr = $self->screen;
    my $sleep_time = $self->sleep_time;
    while( !$_scr->key_pressed ) {
        $self->draw;
        Time::HiRes::sleep $sleep_time;
        $_moves++;
    }
}

sub draw_grid {
    my $self   = shift;
    my $screen = $self->screen;
    my $grid   = $self->screen->grid;
#    $self->screen->clrscr;
    my $rows = $screen->rows;
    my @str;
    $screen->at(0,0);
    for ( 0 .. $rows - 1 ) {
        push @str, map { $_ ? $_->char : " " } @{ $grid->[$_] };
    }
    print @str;
}

my $_move = sub {
    my ( $p, $wantx, $wanty, $grid ) = @_;
    $grid->[$wanty][$wantx] = $p;
    $grid->[ $p->y ][ $p->x ] = undef;
    $p->x($wantx);
    $p->y($wanty);
};

sub move_particles {
    my $self  = shift;
    my $screen = $self->screen;
    my $grid  = $screen->grid;
    for ( @{ $self->particles } ) {
        my $wantx = $screen->xpos( $_->x + $_->xdir );
        my $wanty = $screen->ypos( $_->y + $_->ydir );
        unless ( $grid->[$wanty][$wantx] ) {
            $_move->( $_, $wantx, $wanty, $grid );
        }
        else {
            my $avoid_dir = $_->avoid_dir;
            next unless $avoid_dir;
            my $avoid_dir_string = join ',' => @$avoid_dir;
            $_->num_avoid_tries($_->num_avoid_tries+1);
            $_->tries_in_direction->{$avoid_dir_string}++;
            $wantx = $screen->xpos( $_->x + $avoid_dir->[0] );
            $wanty = $screen->ypos( $_->y + $avoid_dir->[1] );
            unless ( $grid->[$wanty][$wantx] ) {
                $_move->( $_, $wantx, $wanty, $grid );
                $_->successes_in_direction->{$avoid_dir_string}++;
                $_->num_successes( $_->num_successes+1 );
            } elsif( $self->meld ) {
                $_->type( $grid->[$wanty][$wantx]->type );
                $_->clear_xdir;
                $_->clear_ydir;
                $_->clear_char;
            }
        }
    }
}

sub draw {
    my $self = shift;
#   $self->screen->at(0,0);
    $self->move_particles;
#    $self->screen->reset_grid;
    $self->draw_grid;
}

1;

__END__

P(B|A) = P(A|B) * P(A)
        ---------------
            P(B)
