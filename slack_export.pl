#Written by: Steve Lippert
#Version 0.1
#Written: 2016-12-29
#Last Update: 2016-12-29
use strict;

use JSON;
use POSIX 'strftime';
use File::Spec;
use Data::Dumper;
#use DateTime;
use Time::Format qw/%time/;
use 5.14.0;

my ( $input_directory ) = @ARGV;

if ( -d $input_directory ) {
    my ( $channels, $channels_hash, $users, $users_hash, $channels_file, $users_file, @channel_dirs, @files, );
    
    ## Process the Channels file.
    $channels_file = File::Spec->catfile( $input_directory, 'channels.json' );
    open my $CHANNEL_FH, '<', $channels_file;
    my $raw_channels_json = do { local $/; <$CHANNEL_FH> };
    close $CHANNEL_FH;

    eval {
        $channels = JSON->new->utf8->decode( $raw_channels_json );
        for my $channel ( @{$channels} ) {
            $channels_hash->{$channel->{id}} = $channel;
        }
    };

    ## Process the Users file.
    $users_file = File::Spec->catfile( $input_directory, 'users.json' );
    open my $USERS_FH, '<', $users_file;
    my $raw_users_json = do { local $/; <$USERS_FH> };
    close $USERS_FH;

    eval {
        $users = JSON->new->utf8->decode( $raw_users_json );
        for my $user ( @{$users} ) {
            $users_hash->{$user->{id}} = $user;
        }
    };

    opendir( my $DIRH, $input_directory );
    @files = readdir($DIRH);
    closedir $DIRH;

    for my $file ( @files ) {
        next if ( $file =~ /\.+/ || $file =~ /^slack2html_/);

        my ( $channel_dir, $channel_output, $output_file);

        $channel_dir    = File::Spec->catfile( $input_directory, $file );
        $output_file    = File::Spec->catfile( $input_directory, "slack2html_$file.html" );
        $channel_output = <<"OUTPUT";
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>$file</title>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.7/css/bootstrap.min.css">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.7/css/bootstrap.min.css.map">
    </head>
    <body>
        <div class="container">
            <table class="table table-striped">
OUTPUT

        if ( -d $channel_dir ) {
            #say qq|Processing: '$file'|;
            my ( @channel_files, );
            opendir my $CHDH, $channel_dir;
            @channel_files = readdir $CHDH;
            closedir $CHDH;
            
            for my $daily_file ( @channel_files ){
                next if ( $daily_file =~ /^\.+$/);
                #say qq|Processing: $daily_file|;
                my ( $daily_json, $date, $full_path, );

                $full_path = File::Spec->catfile( $channel_dir, $daily_file );
                open my $DAILY_FH, '<', $full_path;
                my $raw_daily_json = do { local $/; <$DAILY_FH> };
                close $DAILY_FH;
                
                $daily_json = JSON->new->utf8->decode($raw_daily_json);
                for my $entry ( @{$daily_json} ) {
                    my ( $time_stamp, $message, $temp_time, );
                    
                    $temp_time  = $entry->{ts};
                    $time_stamp = $time{'yyyy-mm-dd hh:mm', $temp_time};
                    $message    = $entry->{text};
                    $message =~ s/\<@([A-Z0-9]{9})>/\@$users_hash->{$1}->{name}/g;
                    
                    $channel_output .= <<"MESSAGE_OUTPUT";
                    <tr>
                        <td><img src="$users_hash->{ $entry->{user} }->{profile}->{image_48}" /></td>
                        <td>$time_stamp</td>
                        <td>$users_hash->{ $entry->{user} }->{name}: $message</td>
                    </tr>
MESSAGE_OUTPUT
                }
            }
        }

        $channel_output .= <<"FOOTER";
            </table>
        </div>
    </body>
</html>
FOOTER

        open my $OUTPUT_FH, '>', $output_file;
        print $OUTPUT_FH $channel_output;
        close $OUTPUT_FH;
    }
}
