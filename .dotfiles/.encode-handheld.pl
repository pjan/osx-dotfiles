#!/usr/bin/perl
#
# psp encode:
# encode-handheld.pl -f <filename> -t psp
#
# Disregard most comments about specs or ffmpeg as  it may be bunk!
#
# It works, use at your own risk, I am not responsible if your pc blows up!
#
#####################################################################################
#
#                   HOLYROSES WAS HERE!!
#
#####################################################################################
#
# Works on widescreen and non widescreen sources.
#
# PSP files in /VIDEO will not display video and audio bitrate information,
# however they can be named whatever you want.
#
# You currently have to use naming convention MAQxxxxx.MP4 if you are placing in /MP_ROOT/101ANV01
# where xxxxx = digits.
#
# Zune specs:
# http://www.zune.net/en-us/products/compare.htm
# Zune encode specs (though I think its full of bunk):
# http://www.zune.net/en-us/support/usersguide/podcasts/create.htm#section6
#

#http://search.cpan.org/~gbarr/TimeDate-1.19/lib/Date/Format.pm
#use Date::Format;
#http://search.cpan.org/~gbarr/TimeDate-1.19/lib/Date/Parse.pm
use Date::Parse;
use Config;
use Encode;

# stuff that might be useful
#foreach $key (sort(keys %Config)) {
        #print $key, '=', $Config{$key}, "\n";
#}


# Globals
#
use vars qw/ %opt /;

# change if this isn't you
$ripper = "w";
$account_name = 'pieterjan.vandaele@me.com';

# create DD track for Apple TV
# only auto processed from MKV and using option M (extract matroska audio)
# 1 = yes
# 0 = no
$create_dd_track = 1;

# Dolby Digital bit rate in kb
# 640,448,384,224,192
# not recommended going below 384 for 5.1
$dd_bitrate = 384;

# list of types to create a DD track for
$create_dd_type_list = "appletv|ipodntscdvd|ipodpaldvd";

# Automaticaly deinterlace if source is auto detected as DVD
# Far too often are various scenes interlaced in DVD's while 95% of the DVD is progressive...
# This will fix that.
# 1 = yes
# 0 = no
$auto_deinterlace = 1;

# change to whatever is the main audio & video lang you encode to
# use 3 digit code found here:
# http://www.loc.gov/standards/iso639-2/php/code_list.php
$audio_lang = "eng";
$video_lang = "eng";

# default me_range_value
$default_me_range_value = 24;
# set value
$me_range_value = $default_me_range_value;
# range to use for apple tv cavlc
$appletv_cavlc_me_range_value = 24;

# where to put the encoded stuff
$output_folder="$ENV{HOME}/Desktop/Encoded";

# create the output folder if it doesn't exist
if ( ! -d $output_folder ) {
    print "Creating output folder $output_folder\n";
    mkdir $output_folder;
}

# Some hard coded locations where I have ffmpeg and AtomicParsley on my Linux and Mac OS computers
if ( $Config{osname} eq "linux" ) {
    $ffmpeg = "/usr/local/bin/ffmpeg";
        $atomicparsley = "/usr/local/bin/AtomicParsley";
    $jhead = "/usr/bin/jhead";
} elsif ( $Config{osname} eq "darwin" ) {
    $ffmpeg = "/usr/local/bin/ffmpeg-r20921";
    $atomicparsley = "/usr/local/bin/AtomicParsley";
    $jhead = "/usr/bin/jhead";
}

# search for ffmpeg
if ( ! -e $ffmpeg ) {
    $prog_to_find = "ffmpeg";
    $ffmpeg = `which $prog_to_find`;
    chomp $ffmpeg;
    if ( ! -e $ffmpeg ) {
        print STDERR "I'm out of ideas where $prog_to_find could be and I'm not about to search for it.\n";
        print STDERR "Please adjust the location of $prog_to_find in this script.\n";
        exit;
    }
}

# search for optional program
if ( ! -e $atomicparsley ) {
    $prog_to_find = "AtomicParsley";
    $atomicparsley = `which $prog_to_find`;
    chomp $atomicparsley;
    if ( ! -e $atomicparsley ) {
        print STDERR "$prog_to_find not found.  AVC Videos above 320x240 will not play on an iPod 5g, 5.5g.\n";
        print STDERR "Advanced iTunes tagging will also not be performed.\n";
        $atomicparsley_found = 0;
    } else {
        $atomicparsley_found = 1;
    }
} else {
    $atomicparsley_found = 1;
}

# search for optional program
if ( ! -e $jhead ) {
    $prog_to_find = "jhead";
    $jhead = `which $prog_to_find`;
    chomp $jhead;
    if ( ! -e $jhead ) {
        print STDERR "$prog_to_find not found.  Comment in the PSP thumbnail will remain.\n";
        print STDERR "This basically means the thumbail doesn't have a proper JPEG header.\n";
        $jhead_found = 0;
    } else {
        $jhead_found = 1;
    }
} else {
    $jhead_found = 1;
}

# Genre validation, if it not in here it won't take it.
@genres_movie = ("Action & Adventure","Classics","Comedy","Documentary","Drama","Horror","Kids & Family","Music","Romance","Sci-Fi & Fantasy","Short Films","Sports","Thriller","Western","XXX");

@genres_tv = ("Animation","Classic","Comedy","Drama","Kids","Nonfiction","Reality TV","Sci-Fi & Fantasy","Sports");

@genres_mvid = ("Alternative","Country","Hip Hop/Rap","Latino","Pop","R&B/Soul","Rock");

# padding defaults
$padtop = 0;
$padbottom = 0;
$padleft = 0;
$padright = 0;

# version
$version = "5.6";

# default title
$title = "My Video";

# setting NTSC dvd value to 0
$got_dvd = 0;

#
# Command line options processing
#
sub init()
{
    use Getopt::Std;
    my $opt_string = '-piIgaAbhlvxXMZHSs:t:f:n:o:c:z:j:r:d:k:u:y:q:e:E:T:B:L:R:N:K:m:D:C:w:W:Q:';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if $opt{h};
}

#
# Message about this program and how to use it
#
sub usage() {
    print STDERR << "EOF";

    PSP & iPod h264 video and AAC audio encoder.
    PSP Motion JPG encoder.  (22min = 916mb vs 84mb using h264)
    PSP 640x480 16:9 & 4:3 encoder.
    PSP 720x480 16:9 & 4:3 encoder. (To get 4:3 use psp640 with -x)
    PSP 720x576 16:9 & 4:3 encoder. (use psp768 for 4:3 and psp576p for 16:9)
    iPod 720x576 16:9 "PAL DVD" encoder (no 5g/5.5g playback)
    iPod 720x480 16:9 "NTSC DVD" encoder (no 5g/5.5g playback)
    iPod 640x480 16:9 "near DVD" encoder (all iPod OK)
    iPod 480x320 16:9 "half DVD" encoder (all iPod OK)
    iPod 320x240 19:9 & 4:3 encoder (use ipod for 4:3 and ipodwide for 16:9) (all iPod OK)
    Apple TV HD encoder (use -pbI for highest quality)
    Zune 30GB Windows Media 8 A/V encoder.
    Cell phone 176x144 encoder.

    usage: $0 [-hl] [-t psp|psp640|psp640wide|psp768|psp480p|psp576p|pspavi|ipod|ipodwide|ipod480|ipod640|ipoddvd|ipodntscdvd|ipodpaldvd|appletv|zune|zune30|3g2] [-s XXXXX] [-n title] [-f file]

     -h        : this (help) message
     -v        : displays version
     -a        : hard box the video
                 (pillarbox and letterbox the video, AR set to AR of screen size)
     -A        : Auto 16:9 the video.  Your video will be cropped horizontally or vertically until
                 it is at a 16:9 AR.  Works with regular cropping commands as well.  You can crop
                 a DVD matte off and still use -A to force 16:9.
     -g        : letterbox video to next macro block height (ex 480x202 -> 480x208)
     -r        : frame rate (24000/1001 or 30000/1001 are suggested override values) (default 24000/1001)
     -l        : legacy psp file naming
     -s XXXXX  : 5 digit legacy numbering sequence
     -f file   : file to encode
     -n title  : psp title displayed when using legacy naming
                 or file is renamed to this value (if AtomicParsley then also atom)
     -t type   : psp, ipod, zune, zune30, psp640, 3g2 encoding
     -o num    : volume(gain) 1x=256, 2x=512, 3x=768, 4x=1024 (default: No Change)
                 when encoding audio from MKV this controls gain in decibels
                 I don't advise going over +20, as that is extremly loud.  +10 is fine.
     -c num    : thumbnail capture time in seconds (default: 120)
     -C str    : Poster art to add to M4V file. (specify path to jpg or png)
     -z num    : encode time in seconds (default: whole thing)
     -j num    : start encode time in seconds (default: beginning)
     -b        : encode using b frames (psp, appletv) (default: no) (not everything is compatible with this)
     -p        : 2 pass encoding
     -i        : iPhone & iPod touch PSP compatible profile (switches coder to 0)
     -I        : Apple TV CABAC mode. (switches coder to 1 and trellis 2)
                 (This will impact streaming ability, only play while synced)
     -H        : Select High profile (dct8x8 transform) (not compatible with everything, default for appletv)
     -m num    : ffmpeg threads (example, dual core: -m2, quad core: -m4, default 0 (auto))
     -M        : Extract audio from Matroska video files (requires signifcant disk space)
                 only use this for MP4 files destination files.
     -x        : when using type psp640 it will put contents in 720x480 container
                 WARNING: as of PSP firmware v5.0 it does not respect the 8:9 PAR.
                 It will play the video with a 1.5 AR (720/480).
                 The effect is your video will play 80 pixels wider than it should be.
     -X        : force widescreen DVD detection
     -Z        : Save extracted audio from the -M option instead of delete.
     -S        : When processing extracted Matroska audio create a Stereo mix instead of Dolby Pro Logic
     -W str    : The requested width for the movie
                     --  Crop options --
     -T num    : crop top (must be even number)
     -B num    : crop bottom (must be even number)
     -L num    : crop left (must be even number)
     -R num    : crop right (must be even number)
                     --  AtomicParsley options --
     -N str    : name (if not specified then -n is used)
               : this option is used for TV shows (-n "Family Guy s07e01" -N "Love Blactually")
               : example with quotes in title (-N "There's No \\"We\\" Anymore")
     -k str    : artist (req AtomicParsley and type ipod, psp, 3g2)
     -K num/tot : sets tracknum (auto determined, only pass if you want to do a num/tot with example (-K 01/13)
     -u str    : album (req AtomicParsley and type ipod, psp, 3g2)
     -d str    : description (req AtomicParsley and type ipod, psp, 3g2)
     -D str    : long description (req AtomicParsley and type ipod, psp, 3g2)
               : example with quotes in description (-d "Escape \\"quotes\\" on command line.")
     -e str    : genre (req AtomicParsley and type ipod, psp, 3g2)
     -E str/num : iTunes Genre ID number (req AtomicParsley, can pass string or num)
     -w num    : iTunes Catalog ID number (suggest using http://www.imdb.com/ numbers) (can pass tt[num])
               : Should use actual iTunes catalog numbers if available.
     -y value  : year (req AtomicParsley and type ipod, psp, 3g2)
               : pass 4 digits or pass a year string value to encode a Release Date also.
               : see examples below.  (If no value is passed then current year is used.)
     -q str    : US TV & Movie rating (req AtomicParsley and type ipod, psp)
                 us-tv: "TV-MA, TV-14, TV-PG, TV-G, TV-Y, TV-Y7"
                 mpaa: "UNRATED, NC-17, R, PG-13, PG, G"


    note:
    If you end your titles for TV Shows with sXXeXX then it will be parsed correctly as a TV Show.
    If you end your titles for Music Videos with mvid then it will be parsed correctly as a Music Video.

    crop note:
    crop is done to the original video prior to encoding.  AR is recalculated on new crop size.

    year notes:
    If you pass -y XXXX your date will be converted to January 01 of that year.
    If you pass -y "string value" you will get a year timetamp and Release Date information on your MP4 file.
    All string values are converted to UTC.

    Some example valid year strings:
    "July 24, 2007 10pm EST"
    "Mon Jan 26 12:26:13 EST 2009"
    "2009-01-23 21:00:00 EST"
    "2009-01-23 9pm EST"
    "2009-01-23"
    "2009-01-23 EST"
    "19 Dec 1994 EST"
    "oct 2 1994"
    "october 2 1994"
    "october 2 1994 EST"
    "october 19 EST"
    "`date`"

    general usage examples:
    example: $0 -t psp -l -s 10101 -n "My Video" -f file.avi -o 768 -c 120
    example: $0 -t psp -f file.avi
    example: $0 -t psp -f file.avi -n "hookah"
    example: $0 -t zune30 -f file.avi
    example: $0 -t zune30 -f file.avi -n "hookah"
    example: $0 -t ipod -f file.avi
    example: $0 -t ipod -f file.avi -n "hookah"
    example: $0 -t 3g2 -f tvshow.avi -n "TV Show s04e16" -r 24000/1001
    example: $0 -t psp -pi -f tvshow.avi -n "tvshow s01e13" -o 512 -r 24000/1001 -d "Jedi Crash" -q "TV-PG"
    example: $0 -t psp -pi -f rounders.avi -n "Rounders" -o 512 -r 30000/1001 -T 106 -B 102 -L 2 -y 1998 -q R -e Drama -d "Damon plays poker."
    example: $0 -t psp480p -pb -f rounders.avi -n "Rounders" -o 512 -r 30000/1001 -T 106 -B 102 -L 2 -y 1998 -q R -e Drama -d "Damon plays poker."


EOF
exit;
}

init();

#display version
if ( $opt{v} ) {
    print "$0 $version\n\n";
    print "Written by HolyRoses.\n";

    exit;
}

# file selection
if ( ! $opt{f} ) {
    print "Requires [-f file]\n";
    exit;
} else {
    open(FILE, "$opt{f}") or die "Cannot open file <$opt{f}>: $!";
    print "Selected file: $opt{f}\n";
    close(FILE);
    $file = ($opt{f});
}

# Poster art
if ( $opt{C} ) {
    open(POSTER_FILE, "$opt{C}") or die "Cannot open poster art file <$opt{C}>: $!";
    print "Selected poster artwork file: $opt{C}\n";
    close(POSTER_FILE);

    $poster_art = ($opt{C});
    $poster_art_type = (`basename \"$poster_art\"`);
    chomp $poster_art_type;

    $poster_art_type =~ s/.+\.(\w+)$/$1/;

    if ( $poster_art_type !~ /(jpg|png)/i ) {
        print STDERR "ERROR: Poster art is not type jpg or png.\n";
        exit;
    }
}

# checking if we are going to be extracting Matroska audio
if ( $opt{M} ) {
    print "Choosing to extract audio from Matroska files\n";

    $mkvextract = `which mkvextract`;
    chomp $mkvextract;

    $mkvmerge = `which mkvmerge`;
    chomp $mkvmerge;

    $a52dec = `which a52dec`;
    chomp $a52dec;

    $dcadec = `which dcadec`;
    chomp $dcadec;

    @programs = ($mkvextract,$mkvmerge,$a52dec,$dcadec);

    foreach (@programs) {
            if ( ! -e $_) {
                    print STDERR "You are missing a program, this script requires the following programs:\n";
                    print STDERR "mkvextract mkvmerge a52dec dcadecn";
            exit;
            }
    }
}

# ffmpeg pass
$pass = 0;

$crop_line = "";
$croptop = 0;
$cropbottom = 0;
$cropleft = 0;
$cropright = 0;

if ( $opt{T} ) {
    $croptop = $opt{T};
    if ( $croptop =~ /^(\d+)$/ ) {
        print "Crop top = $croptop\n";
    } else {
        print STDERR "ERROR: Crop top requires integer value\n";
        exit;
    }

    if ( $croptop =~ /(1|3|5|7|9)$/ ) {
        print STDERR "ERROR: Crop top requires even value\n";
        exit;
    }

    $cropping = 1;
}

if ( $opt{B} ) {
    $cropbottom = $opt{B};
    if ( $cropbottom =~ /^(\d+)$/ ) {
        print "Crop bottom = $cropbottom\n";
    } else {
        print STDERR "ERROR: Crop bottom requires integer value\n";
        exit;
    }
    if ( $cropbottom =~ /(1|3|5|7|9)$/ ) {
        print STDERR "ERROR: Crop bottom requires even value\n";
        exit;
    }
    $cropping = 1;
}

if ( $opt{L} ) {
    $cropleft = $opt{L};
    if ( $cropleft =~ /^(\d+)$/ ) {
        print "Crop left = $cropleft\n";
    } else {
        print STDERR "ERROR: Crop left requires integer value\n";
        exit;
    }
    if ( $cropleft =~ /(1|3|5|7|9)$/ ) {
        print STDERR "ERROR: Crop left requires even value\n";
        exit;
    }
    $cropping = 1;
}

if ( $opt{R} ) {
    $cropright = $opt{R};
    if ( $cropright =~ /^(\d+)$/ ) {
        print "Crop right = $cropright\n";
    } else {
        print STDERR "ERROR: Crop right requires integer value\n";
        exit;
    }
    if ( $cropright =~ /(1|3|5|7|9)$/ ) {
        print STDERR "ERROR: Crop right requires even value\n";
        exit;
    }
    $cropping = 1;
}

# amount of times to loop through encoding
if ( $opt{p} ) {
    $loops = 2;
} else {
    $loops = 1;
}

# set rate if passed
if ( $opt{r} ) {
    $rate = "-r $opt{r}";
    print "Setting frame rate to $rate\n";
} else {
    print "Defaulting frame rate to 23.976.\n";
    $rate = "-r 24000/1001";
}

# ffmpeg threads
# set $threads_line to a default value if you want
# ffmpeg to always use a threaded encode and
# you dont want to pass "-m XX" everytime.
# if you have dual core use 2, quad 4, etc
#
# uncomment line below and just hard code the value you want
#$threads_line = "-threads 2";
if ( $opt{m} ) {
    $threads = $opt{m};
    if ( $threads =~ /^(\d+)$/ ) {
        print "ffmpeg threads = $threads\n";
    } else {
        print STDERR "ERROR: ffmpeg threads requires integer value\n";
        exit;
    }

    $threads_line = "-threads $threads";
} else {
    print "Defaulting threads to 0 (auto).\n";
    $threads = 0;
    $threads_line = "-threads $threads";
}

# encode time
if ( $opt{z} ) {
    if ( $opt{z} =~ /^(\d+)$/ ) {
        print "Encode time: $opt{z}\n";
        $time = "-t $opt{z}";
    } else {
        print STDERR "ERROR: start time requires integer value\n";
        exit;
    }
}

# start time
if ( $opt{j} ) {
    if ( $opt{j} =~ /^(\d+)$/ ) {
        print "Selected start time: $opt{j}\n";
        $start_time = "-ss $opt{j}";
    } else {
        print STDERR "ERROR: start time requires integer value\n";
        exit;
    }
}


# sequence
if ( $opt{s} ) {
    if (! $opt{l}) {
        print STDERR "ERROR: number sequencing requires option [-l]\n";
        exit;
    }
    if ( $opt{t} ne "psp" ) {
        print STDERR "ERROR: number sequencing requires option [-t psp]\n";
        exit;
    }
    if ( $opt{s} =~ /^(\d{5})$/ ) {
        print "Selected Legacy number: $opt{s}\n";
        $sequence = ($opt{s});
    } else {
        print STDERR "ERROR: Legacy sequence invalid: $opt{s}\n";
        exit;
    }

}

# psp title
if ( $opt{n} ) {
    print "Selected title: $opt{n}\n";
    $title = ($opt{n});
} else {
    if ( $opt{t} eq "zune30" ) {
        print STDERR "ERROR:\n";
        print STDERR "Zune displays title information when you display movie in Zune or Zune software.\n";
        print STDERR "Please provide a title with -n \"Title\"\n";
        exit;
    }
}

# volume
if ( $opt{o} ) {
    if ( $opt{o} =~ /^[-+]?(\d+)$/ ) {
        # -vol volume         change audio volume (256=normal)
        #
        # 256 = 100% (normal)
        # 512 = 200%
        # 768 should be 300%
        # 1024 should be 400%
        $vol = "-vol $opt{o}";
        # some coding for gain control when using a52dec or dcadec
        if ( $opt{M} ) {
            if ( $opt{o} =~ /^[-+](\d+)$/ ) {
                $gain = "-g $opt{o}";
                if ( $1 > 50 ) {
                    print STDERR "ERROR: Your GAIN value is crazy high, try between +10 and +50\n";
                    exit;
                }
            } else {
                print STDERR "ERROR: Gain requires a positive or negative value.\n";
                exit;
            }
        } else {
            if ( $opt{o} =~ /^[-+](\d+)$/ ) {
                print STDERR "ERROR: You are using +gain values for Matroska extracted audio\n";
                print STDERR "ERROR: Use values such as 512, 768, 1024 if not processing MKV audio.\n";
                exit;
            }
        }
        print "Selected volume: $opt{o}\n";
    } else {
        print STDERR "ERROR: Volume requires integer value\n";
        exit;
    }
} else {
    #$vol = "-vol 512";
    print "Selected Volume: No Change\n";
}

# thumbnail time
if ( $opt{c} ) {
    if ( $opt{c} =~ /^(\d+)$/ ) {
        print "Selected thumbnail time: $opt{c}\n";
        $thumbtime = ($opt{c});
    } else {
        print STDERR "ERROR: Thumbnail time requires integer value\n";
        exit;
    }
} else {
    print "Selected thumbnail time: 120\n";
    $thumbtime = 120;
}

if ( $atomicparsley_found == 1) {
    $got_long_description = 0;
    open(CHECK_AP_OPTIONS, "$atomicparsley -h 2>/dev/null |");
    while(<CHECK_AP_OPTIONS>) {
        if ( /longDescription/ ) {
            $got_long_description = 1;
            $longdesc = "--longDescription";
        }
        if ( /longdesc/ ) {
            $got_long_description = 1;
            $longdesc = "--longdesc";
        }
        if ( /apID/ ) {
            $got_apid = 1;
        }
        if ( /cnID/ ) {
            $got_cnid = 1;
        }
        if ( /geID/ ) {
            $got_geid = 1;
        }
        if ( /hdvideo/ ) {
            $got_hdvideo = 1;
        }
        if ( /encodedBy/ ) {
            $got_encodedby = 1;
        }
    }
    close(CHECK_AP_OPTIONS);

$iTunMOVI_data = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>copy-warning</key>
    <string>Help control the pet population. Have your pets spayed or neutered.</string>
    <key>studio</key>
    <string>A $ripper Production</string>
    <key>producers</key>
    <array>
        <dict>
            <key>name</key>
            <string>$ripper</string>
        </dict>
    </array>
</dict>
</plist>
";

    $contentRating = "";
    $tracknum = "";

    if ( $title =~ /\s-\s/ ) {
        print "converting SpaceDashSpace in title to :Space\n";
        $title =~ s/(.+)\s-\s(.+)/$1: $2/;
        #$title =~ s/(Star Wars)\s-\s(.+)/$1: $2/;
        print "modified title will be \"$title\"\n";
    }

    if ( $title =~ /(s(\d+)e(\d+))/i ) {
        $tvepisode = $1;
        $tvseasonnum = $2;
        $tvepisodenum = $3;
        if ( $opt{K} ) {
            $tracknum = "--tracknum $opt{K}";
        } else {
            $tracknum = "--tracknum $3";
        }
        $stik = "TV Show";
        $tvshowname = $title;
        $tvshowname =~ s/(.+)\s+($tvepisode)/$1/;
    } elsif ( $title =~ /mvid/i ) {
        $stik = "Music Video";
        $title =~ s/(.+)\s+mvid/$1/i;
    } else {
        $stik = "Short Film";
    }

    if ( $opt{D} ) {
        $long_description = $opt{D};

        #convert to utf8
        $octets = encode("utf8", $long_description);
        $long_description=$octets;
    }


    if ( $opt{d} ) {
        $description = $opt{d};

        #convert to utf8
        $octets = encode("utf8", $description);
        $description=$octets;

        $chars = length($description);

        if ($chars > 255 ) {
                print "WARNING: description has too many characters: $chars.  Max 255.  Reducing...\n";
            if ( ! $opt{D} ) {
                $long_description = $description;
                print "Assigning description to long description\n";
            }
                $str = qq{$description};
                $str = substr($str,0,255);
                $description = $str;
                print "NEW description is:\n";
                print "$description\n";
        }
    } else {
        $description = "$ripper for president!";
    }

    if ( ! $long_description ) {
        $long_description = $description;
    }

    if ( $opt{q} ) {
        $rating = $opt{q};
        if ( $stik eq "TV Show" ) {
            if ( $rating eq "TV-MA" ) {
                $rating_ok = 1;
            } elsif ( $rating eq "TV-14" ) {
                $rating_ok = 1;
            } elsif ( $rating eq "TV-PG" ) {
                $rating_ok = 1;
            } elsif ( $rating eq "TV-G" ) {
                $rating_ok = 1;
            } elsif ( $rating eq "TV-Y" ) {
                $rating_ok = 1;
            } elsif ( $rating eq "TV-Y7" ) {
                $rating_ok = 1;
            } else { $rating_ok = 0; }
        } elsif ( $stik eq "Short Film" ) {
            if ( $rating eq "UNRATED" ) {
                $rating_ok = 1;
            } elsif ( $rating eq "NC-17" ) {
                $rating_ok = 1;
            } elsif ( $rating eq "R" ) {
                $rating_ok = 1;
            } elsif ( $rating eq "PG-13" ) {
                $rating_ok = 1;
            } elsif ( $rating eq "PG" ) {
                $rating_ok = 1;
            } elsif ( $rating eq "G" ) {
                $rating_ok = 1;
            } else { $rating_ok = 0; }
        }

        if ( $rating_ok == 0 ) {
            print STDERR "The selected rating \"$rating\" for $stik is not a valid choice.\n";
            print STDERR "us-tv: TV-MA, TV-14, TV-PG, TV-G, TV-Y, TV-Y7\n";
            print STDERR "mpaa: UNRATED, NC-17, R, PG-13, PG, G\n";
            exit;
        } else {
            $contentRating = "--contentRating \"$rating\"";
        }
    }

    # process passed year
    if ( $opt{y} ) {
        if ( $opt{y} =~ /^\d{4}$/) {
            $itunes_year = "$opt{y}-01-01T00:00:00Z";
        } else {
            $unix_time = str2time($opt{y});
            get_date("gmtime");
            $itunes_year = "${year}-${mon}-${mday}T${hour}:${min}:${sec}Z";
        }
    } else {
        # no year string was passed to script
        # just generate one based on current time
        $unix_time = (time);
        get_date("gmtime");
        $itunes_year = "${year}-${mon}-${mday}T${hour}:${min}:${sec}Z";
    }

    # Playing around with copyright...
    $unix_time = (time);
    get_date("localtime");
    $year_small = $year;

    # not sure why it needs "latin capital letter A with circumflex" in front of the copyright symbol but it does.
    # now know why.  It is because it is UTF-8 and copyright symbol is represented by 2 bytes in UTF-8
    # so iTunes must read UTF-8 characters or expect them at least.
    #
    # reference:
    # http://www.fileformat.info/info/unicode/char/00a9/index.htm
    # http://forum.joomla.org/viewtopic.php?f=11&t=79979
    # UTF-8 (hex) 0xC2 0xA9 (c2a9)
    $copyright = "\x{c2}\x{a9} $year_small $ripper. All Rights Reserved.";

    if ( $opt{u} ) {
        $album = $opt{u};
    } elsif ( $stik eq "TV Show" ) {
        $nozero_tvseasonnum = $tvseasonnum;
        $nozero_tvseasonnum =~ s/0+(\d+)/\1/;
        $album = "$tvshowname, Season $nozero_tvseasonnum";

    } else {
        $album = "";
    }

    if ( $opt{e} ) {
        $genre_temp = $opt{e};
        # genre validation, NOT geID
        if ( ($stik eq "Short Film" || $stik eq "TV Show" || $stik eq "Music Video") ) {
            $genre_match = 0;
            if ( $stik eq "Short Film" ) {
                if ( $genre_temp =~ /crime/i ) {
                    print "Changing genre $genre_temp to Drama\n";
                    print "This may not be what you want!\n";
                    $genre_temp = "Drama";
                } elsif ( $genre_temp =~ /biography/i ) {
                    print "Changing genre $genre_temp to Documentary\n";
                    print "This may not be what you want!\n";
                    $genre_temp = "Documentary";
                } elsif ( $genre_temp =~ /animation/i ) {
                    print "Changing genre $genre_temp to Kids & Family\n";
                    print "This may not be what you want!\n";
                    $genre_temp = "Kids & Family";
                }

                foreach (@genres_movie) {
                    if ( "$_" =~ /.*$genre_temp.*/i ) {
                        print "Genre match: \"$genre_temp\" =~ \"$_\"\n";
                        $genre_temp = $_;
                        $genre_match = 1;
                        if ( ! $opt{E} ) {
                            if ( $genre_temp eq "XXX" ) {
                                $geID=4412;
                                print "Since geID wasn't passed we will use Romance => $geID\n";
                            } else {
                                genreIDs();
                                $geID="$geIDMovie{\"$genre_temp\"}";
                                print "Since geID wasn't passed we will use $genre_temp => $geID\n";
                            }
                        }
                        last;
                    }
                }
            } elsif ( $stik eq "TV Show" ) {
                foreach (@genres_tv) {
                    if ( "$_" =~ /.*$genre_temp.*/i ) {
                        print "Genre match: \"$genre_temp\" =~ \"$_\"\n";
                        $genre_temp = $_;
                        $genre_match = 1;
                        if ( ! $opt{E} ) {
                            genreIDs();
                            $geID="$geIDTV{\"$genre_temp\"}";
                            print "Since geID wasn't passed we will use $genre_temp => $geID\n";
                        }
                        last;
                    }
                }
            } elsif ( $stik eq "Music Video" ) {
                foreach (@genres_mvid) {
                    if ( "$_" =~ /.*$genre_temp.*/i ) {
                        print "Genre match: \"$genre_temp\" =~ \"$_\"\n";
                        $genre_temp = $_;
                        $genre_match = 1;
                        if ( ! $opt{E} ) {
                            genreIDs();
                            $geID="$geIDmvid{\"$genre_temp\"}";
                            print "Since geID wasn't passed we will use $genre_temp => $geID\n";
                        }
                        last;
                    }
                }
            }

            # Nothing passed above
            if ( $genre_match == 0) {
                print STDERR "The genre you entered \"$genre_temp\" is not a valid genre type for \"$stik\".\n";
                exit();
            }
        }

        if ( $opt{t} eq "3g2" ) {
            $genre = "--3gp-genre \"$genre_temp\"";
        } else {
            $genre = "--genre \"$genre_temp\"";
        }
    } else {
        $genre = "";
        if ( $got_geid == 1 ) {
            # media kind determined to be video but genre nor geID were passed
            if ( ($stik eq "Short Film" || $stik eq "TV Show" || $stik eq "Music Video" ) && ! $opt{E} ) {
                if ( $stik eq "Short Film" ) {
                    $geID=33;
                    $genre_temp = "Movies";
                    print "Auto setting $stik geID & genre to Movies => $geID\n";
                } elsif ( $stik eq "TV Show" ) {
                    $geID=32;
                    $genre_temp = "TV Shows";
                    print "Auto setting $stik geID & genre to TV Shows => $geID\n";
                } else {
                    $geID=31;
                    $genre_temp = "Music Videos";
                    print "Auto setting $stik geID & genre to Music Videos => $geID\n";
                }

                if ( $opt{t} eq "3g2" ) {
                    $genre = "--3gp-genre \"$genre_temp\"";
                } else  {
                    $genre = "--genre \"$genre_temp\"";
                }
            }
        }
    }

    #geID processing
    if ( $opt{E} ) {
        if ( $got_geid == 1 ) {
            $geID = "$opt{E}";
            #populate hash's
            genreIDs();
            # process strings that were passed as geID's
            if ( $geID !~ /^(\d+)$/ ) {
                if ( $stik eq "Short Film" ) {
                    if ( exists $geIDMovie{$geID} ) {
                        print "Converting geID string \"$geID\" to \"$geIDMovie{$geID}\"\n";
                        if ( ! $opt{e} ) {
                            $genre_temp = $geID;
                            print "Since no genre was passed auto setting genre to \"$genre_temp\"\n";
                            $genre = "--genre \"$genre_temp\"";
                        }
                        $geID = "$geIDMovie{$geID}";
                    } else {
                        print STDERR "The geID string value you passed \"$geID\" is not valid for media type \"$stik\".\n";
                        exit();
                    }
                } elsif ( $stik eq "TV Show" ) {
                    if ( exists $geIDTV{$geID} ) {
                        print "Converting geID string \"$geID\" to \"$geIDTV{$geID}\"\n";
                        if ( ! $opt{e} ) {
                            $genre_temp = $geID;
                            print "Since no genre was passed auto setting genre to \"$genre_temp\"\n";
                            $genre = "--genre \"$genre_temp\"";
                        }
                        $geID = "$geIDTV{$geID}";
                    } else {
                        print STDERR "The geID string value you passed \"$geID\" is not valid for media type \"$stik\".\n";
                        exit();
                    }
                } elsif ( $stik eq "Music Video" ) {
                    if ( exists $geIDmvid{$geID} ) {
                        print "Converting geID string \"$geID\" to \"$geIDmvid{$geID}\"\n";
                        if ( ! $opt{e} ) {
                            $genre_temp = $geID;
                            print "Since no genre was passed auto setting genre to \"$genre_temp\"\n";
                            $genre = "--genre \"$genre_temp\"";
                        }
                        $geID = "$geIDmvid{$geID}";
                    } else {
                        print STDERR "The geID string value you passed \"$geID\" is not valid for media type \"$stik\".\n";
                        exit();
                    }
                } else {
                    print STDERR "NOT passing geID \"$geID\" due to no data for this media type \"$stik\"\n";
                    print STDERR "Use a number if you want to bypass controls for unknown data types\n";
                    print STDERR "Might be best not to specify and use auto selection.\n";
                    print STDERR "How did you manage to even get here?\n";
                    exit();
                }
            } else {
                $genre_match = 0;
                if ( $stik eq "Short Film" ) {
                    while (  my ($key, $value) = each(%geIDMovie) ) {
                        if ( $geID == $value ) {
                            if ( ! $opt{e} ) {
                                $genre_temp = $key;
                                print "Since no genre was passed auto setting genre to \"$genre_temp\"\n";
                                $genre = "--genre \"$genre_temp\"";
                            }
                            print "geID match: \"$geID\" => \"$key\" is valid media type \"$stik\"\n";
                            $genre_match = 1;
                            last;
                        }
                    }
                } elsif ( $stik eq "TV Show" ) {
                    while (  my ($key, $value) = each(%geIDTV) ) {
                        if ( $geID == $value ) {
                            if ( ! $opt{e} ) {
                                $genre_temp = $key;
                                print "Since no genre was passed auto setting genre to \"$genre_temp\"\n";
                                $genre = "--genre \"$genre_temp\"";
                            }
                            print "geID match: \"$geID\" => \"$key\" is valid media type \"$stik\"\n";
                            $genre_match = 1;
                            last;
                        }
                    }
                } elsif ( $stik eq "Music Video" ) {
                    while (  my ($key, $value) = each(%geIDmvid) ) {
                        if ( $geID == $value ) {
                            if ( ! $opt{e} ) {
                                $genre_temp = $key;
                                print "Since no genre was passed auto setting genre to \"$genre_temp\"\n";
                                $genre = "--genre \"$genre_temp\"";
                            }
                            print "geID match: \"$geID\" => \"$key\" is valid media type \"$stik\"\n";
                            $genre_match = 1;
                            last;
                        }
                    }
                } else {
                    # How someone is here is beyond me. hackers!
                    if ( $geID > 4294967295 ) {
                        print STDERR "geID is an unsigned 32bit integer and has a max value of 4,294,967,295.\n";
                        print STDERR "Please reduce the value\n";
                        exit();
                    }
                    print "Passing geID \"$geID\" due to no data for this type \"$stik\"\n";
                    print "Validation tables do not exist, hope you know what you are doing.\n";
                    $genre_match = 1;
                }

                # only way to reach here is if type was Short Film, TV Show, or Music Video
                if ( $genre_match == 0 ) {
                    print STDERR "geID \"$geID\" is not a valid identifier for media type \"$stik\"\n";
                    exit();
                }
            }
        } else {
            print STDERR "geID not in AtomicParsley, will not encode iTunes genre ID\n";
        }
    }

    if ( $opt{k} ) {
        $artist = $opt{k};
    } elsif ( $stik eq "TV Show" ) {
        $artist = "$tvshowname";
    } else {
        $artist = "$ripper";
    }

    $encodingtool = "encode-handheld-${version}.pl";
    $purchasedate = "timestamp";
    $comment = "A $ripper Production - http://thepiratebay.org/user/$ripper/";

    # set HD flag
    if ( $opt{t} eq "appletv" && $got_hdvideo == 1 ) {
        $hdvideo = "--hdvideo true";
    }

    # Set Account Name (apID)
    if ( $got_apid == 1 ) {
        $apid = "--apID $account_name";
    }

    # Set Encoded By (enc)
    if ( $got_encodedby == 1 ) {
        $encodedby = "--encodedBy $ripper";
    }

    if ( $opt{w} ) {
        if ( $got_cnid == 1 ) {
            # Passed iMDB title number
            if ( $opt{w} =~ /^tt(\d+)$/ ) {
                $opt{w} = $1;
            }

            if ( $opt{w} =~ /^\d+$/ ) {
                if ( $opt{w} > 4294967295 ) {
                    print STDERR "cnID is an unsigned 32bit integer and has a max value of 4,294,967,295.\n";
                    print STDERR "Please reduce the value\n";
                    exit;
                } else {
                    $cnid = "--cnID $opt{w}";
                }
            } else {
                print STDERR "iTunes Catalog ID must be numbers only\n";
                exit;
            }
        } else {
            print STDERR "cnID not in AtomicParsley, will not encode iTunes catalog ID\n";
        }
    }
}

sub trim
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

open (FILE, "ffmpeg -i \"$file\" 2>&1 |");
while (<FILE>)
{
    my $line = $_;
    next unless ($line =~ m/^\s+Stream #.+?: Video/);
    my @pieces = split (',', $line);
    my @vsize = split (' ', trim ($pieces[2]));
    my @vbits = split (' ', trim ($pieces[3]));
    my $video_size = trim (shift @vsize);
    my $video_bits = trim (shift @vbits);
    print "$video_size $video_bits\n";
    my @video_sizes = split ('x', $video_size);
    $vid_width = trim (shift @video_sizes);
    $vid_height = trim (shift @video_sizes);
    $video_aspect_ratio = ($vid_width/$vid_height);
    last;
}
close(FILR);




open(SIZE, "$ffmpeg -i \"$file\" 2>&1 |");
while(<SIZE>) {
    # NTSC DVD video lines
    #Stream #0.0[0x1e0]: Video: mpeg2video, yuv420p, 720x480 [PAR 32:27 DAR 16:9], 9000 kb/s, 59.94 tb(r)
    #Stream #0.0[0x1e0]: Video: mpeg2video, yuv420p, 720x480 [PAR 8:9 DAR 4:3], 9000 kb/s, 59.94 tb(r)

    # PAL DVD
        #Stream #0.0[0x1e0]: Video: mpeg2video, yuv420p, 720x576 [PAR 64:45 DAR 16:9], 7500 kb/s, 25.00 tb(r)
    #Stream #0.0[0x1e0]: Video: mpeg2video, yuv420p, 720x576 [PAR 16:15 DAR 4:3], 7200 kb/s, 25 tbr, 90k tbn, 50 tbc
    if (/Video: \w+, \w+, (\d+)x(\d+)/) {
        $width = $1;
        $height = $2;
        print "test";
        print "video dimensions = ${width}x${height}\n";

        $video_aspect_ratio = ($width/$height);

        # I know this is hackey, shut it.
        # should be in the main match, but I no longer know how backwards compatible
        # ffmpeg is and this output line is.
        # this is only used for MKV files which do not have the video track as track 0
        if ( /Stream #(\d+)\.(\d+)/ ) {
            $video_source = $1;
            $video_track = $2;
        }

        # checking for DVD's
        if (/Video: \w+, \w+, (\d+)x(\d+) \[PAR (\d+):(\d+) DAR (\d+):(\d+)\]/) {
            # testing for NTSC dvd dimensions
            if ( $width == 720 && $height == 480 ) {
                # hardset widescreen if opt X
                # sometimes ffmpeg fails detection and defaults to 4x3
                if ( $opt{X} ) {
                    $video_aspect_ratio = (16/9);
                    $width = 854;
                    $rate = "-r 24000/1001";
                    print "Hard setting Widescreen DVD, setting frame rate to $rate\n";
                    $got_dvd = 1;
                    $wide = 1;
                } elsif ( $5 == 16 && $6 == 9 ) {
                    $video_aspect_ratio = ($5/$6);
                    #$par = (($height*$video_aspect_ratio)/$width); # 32/27
                    #$width = ($width*$par);
                    $width = 854;
                    $rate = "-r 24000/1001";
                    print "Detected NTSC Widescreen DVD, setting frame rate to $rate\n";
                    $got_dvd = 1;
                    $wide = 1;
                } elsif ( $5 == 4 && $6 == 3 ) {
                    $video_aspect_ratio = ($5/$6);
                    $width = 640;
                    $rate = "-r 24000/1001";
                    print "Detected NTSC Fullscreen DVD, setting frame rate to $rate\n";
                    $got_dvd = 1;
                    $wide = 0;
                }
            }

            # testing for PAL dvd dimensions
            if ( $width == 720 && $height == 576 ) {
                # hardset widescreen if opt X
                # sometimes ffmpeg fails detection and defaults to 4x3
                if ( $opt{X} ) {
                    $video_aspect_ratio = (16/9);
                    $width = 1024;
                    $rate = "-r 25/1";
                    print "Hard setting PAL Widescreen DVD, setting frame rate to $rate\n";
                    $got_dvd = 1;
                    $wide = 1;
                } elsif ( $5 == 16 && $6 == 9 ) {
                    $video_aspect_ratio = ($5/$6);
                    #$par = (($height*$video_aspect_ratio)/$width); # 32/27
                    #$width = ($width*$par);
                    $width = 1024;
                    $rate = "-r 25/1";
                    print "Detected PAL Widescreen DVD, setting frame rate to $rate\n";
                    $got_dvd = 1;
                    $wide = 1;
                } elsif ( $5 == 4 && $6 == 3 ) {
                    $video_aspect_ratio = ($5/$6);
                    $width = 768;
                    $rate = "-r 25/1";
                    print "Detected PAL Fullscreen DVD, setting frame rate to $rate\n";
                    $got_dvd = 1;
                    $wide = 0;
                }
            }
        }
    }

    if ( /2997003\/125000/ ) {
        #$rate = "-r 30000/1001";
        # setting rate to 23.976 (film)
        $rate = "-r 24000/1001";
        print "Odd Container rate found. Forcing frame rate to $rate\n";
        print "This should fix the following error in QT\n";
        print "Error -2002: a bad public atom was found in the movie\n";
    }
    # cyber shot detection changed
    #if ( /Audio: mp2, 32000 Hz, mono,/ ) {
    #}
    if ( /Audio: mp2, 32000 Hz, 1 channels,/ ) {
        print "Sony Cyber-Shot video stream detected, copying audio settings\n";
        $copy_audio_settings = 1;
    }
    # flip video detection
    if ( /Audio: adpcm_ms, 44100 Hz, 1 channels/ ) {
        print "Flip Video stream detected, copying audio settings\n";
        $copy_audio_settings = 1;
    }

    #Seems stream 0 codec frame rate differs from container frame rate: 23.98 (65535/2733) -> 23.98 (2997/125)
    #if ( /65535\/2733/ ) {
        #$rate = "-r 24000/1001";
        #print "Odd Container rate found.  Setting rate manually to $rate\n";
    #}
}
close(SIZE);

print "video aspect ratio = $video_aspect_ratio\n";

if ( $cropping ) {
    $crop_vertical = ($croptop + $cropbottom);
    $crop_horizontal = ($cropleft + $cropright);
    $height = ($height - $crop_vertical);
    $width = ($width - $crop_horizontal);

    $video_aspect_ratio = ($width/$height);

    print "cropped video dimensions = ${width}x${height}\n";
    print "cropped video aspect ratio = $video_aspect_ratio\n";

    $crop_line = "-croptop $croptop -cropbottom $cropbottom -cropleft $cropleft -cropright $cropright";
    $thumb_crop_line = "$crop_line";
}

# auto crop to 16:9 mode
if ( $opt{A} ) {
    print "Auto 16:9 crop mode activated\n";
    #print "Current Aspect is $video_aspect_ratio\n";
    $ar_needs_checking = 1;
    while ($ar_needs_checking == 1) {
        if ( $video_aspect_ratio =~ /1\.77/) {
            $ar_needs_checking = 0;

            if ($auto_cropping == 1) {
                print "Auto 16:9 cropped video dimensions = ${width}x${height}\n";
                print "Auto 16:9 cropped video aspect ratio = $video_aspect_ratio\n";
                print "cropleft is $cropleft - cropright is $cropright\n";
                print "cropbottom is $cropbottom - croptop is $croptop\n";

                $crop_line = "-croptop $croptop -cropbottom $cropbottom -cropleft $cropleft -cropright $cropright";
                $thumb_crop_line = "$crop_line";
            } else {
                print "Aspect is correct and needs no further modification\n";
            }
        } elsif ( $video_aspect_ratio > 1.77 ) {
            $auto_cropping = 1;

            $width = ( $width - 2 ) ;
            $video_aspect_ratio = ($width/$height);

            $crop_horizontal = ($crop_horizontal + 2);

            if ( $crop_horizontal > 2 ) {
                $cropleft = ($crop_horizontal/2);
                $cropright = $cropleft;

                if ( $cropleft =~ /(1|3|5|7|9)$/ ) {
                    $cropleft++;
                    $cropright--;
                }
            } else {
                $cropright = 2;
            }
            #For debug purposes
            #print "Video horizontal cropped, AR now $video_aspect_ratio\n";
        } else {
            $auto_cropping = 1;

            $height = ( $height - 2 ) ;
            $video_aspect_ratio = ($width/$height);

            $crop_vertical = ($crop_vertical + 2);

            if ( $crop_vertical > 2 ) {
                $croptop = ($crop_vertical/2);
                $cropbottom = $croptop;

                if ( $croptop =~ /(1|3|5|7|9)$/ ) {
                    $cropbottom++;
                    $croptop--;
                }
            } else {
                $cropbottom = 2;
            }
            #For debug purposes
            #print "Video vertical cropped, AR now $video_aspect_ratio\n";
        }

    }
}

# examintion of iTunes HD content is they use
# High Profile 3.1
# using dct8x8 activates High Profile
if ( $opt{t} eq "appletv" ) {
    #dct8x8                  E.V.. high profile 8x8 transform (H.264)
    $dct8x8 = "+dct8x8";
}

# High profile was selected (default for appletv)
if ( $opt{H} ) {
        #dct8x8                  E.V.. high profile 8x8 transform (H.264)
        $dct8x8 = "+dct8x8";
}

# set deinterlace variable to a value
if ( $got_dvd == 1 && $auto_deinterlace == 1 ) {
    $deinterlace = "-deinterlace";
    print "Automatically deinterlacing this DVD source\n";
}

# set some default ffmpeg options
$ffmpeg_codec_option = "-formats";
$me_method = "-me_method";

# refer to bottom of script to read more about the x264 changes and the need for this segment
open(CHECK_FFMPEG_OPTIONS, "$ffmpeg -h 2>/dev/null |");
while(<CHECK_FFMPEG_OPTIONS>) {
    # check to see if we have the new metadata option
    if ( /metadata/ ) {
        $meta_data = 1;
    }

    # determine me method
    # method depends on ffmpeg old version used -me
    if (/^-me\s/) {
        $me_method = "-me";
    }

    # while we are here we might as well check for weight p frames
    # and disable, not sure this is compatible with
    # appletv, ipods, psp, etc
    if ( /wpredp/ ) {
        $wpredp = "-wpredp 0";
    }

    # check for mbtree too
    # and enable if found
    if (/mbtree/ ) {
        $mbtree = "+mbtree";
    }

    # check for vlang (recently added)
    if ( /vlang/ ) {
        $vlang = "-vlang $video_lang";
    }

    # handle split of -formats commands
    if ( /-codecs\s+/ ) {
        $ffmpeg_codec_option = "-codecs";
    }

    if ( /brdo/ ) {
        $brdo_found = 1;
    }
}
close(CHECK_FFMPEG_OPTIONS);

# psp doesn't seem to mind bf 16
# quicktime struggles like hell trying to play with bframes set to 16
# you get pixel corruption and very sluggish performance
# use the default of 3 bf
if ( $opt{t} eq "psp" ) {
    $bframes_value = 16;
} else {
    # set default b frames value
    $bframes_value = 3;
}

# process B flags
if ( $brdo_found == 1 ) {
    if ( $opt{b} ) {
        $bflags = "-flags2 +wpred+brdo+mixed_refs$dct8x8$mbtree -bidir_refine 1 -bf $bframes_value -b_strategy 1";
    } else {
        #$bflags = "-flags2 +mixed_refs".$dct8x8.$mbtree;
    }
    $subq = "-subq 7";
} else {
    # newer ffmpeg with new x264
    # --bime (-bidir_refine) removed, auto at subme (-subq) >= 5
    # --b-rdo (-flags2 +brdo) removed, auto at subme (-subq) >= 7
    # RD refinement was part of old subme 7 and was only on I/P frames
    if ( $opt{b} ) {
        $bflags = "-flags2 +wpred+mixed_refs$dct8x8$mbtree -bf $bframes_value -b_strategy 1";
        # bonus of RD refinement in B frames
        $subq = "-subq 9";
    } else {
        #$bflags = "-flags2 +mixed_refs".$dct8x8.$mbtree;
        $subq = "-subq 8";
    }
}

# type selection
if ( ! $opt{t} ) {
    print STDERR "ERROR: Requires [-t psp|psp640|psp640wide|psp768|psp480p|psp576p|pspavi|ipod|ipodwide|ipod480|ipod640|ipoddvd|ipodntscdvd|ipodpaldvd|appletv|zune|zune30|3g2]\n";
    exit;
} else {
    if ( $opt{t} =~ /^ipod$|^ipod640|^appletv$/ ) {
        print "Selected type: $opt{t}\n";
        $format = "mp4";
        open(CHECK_CODECS, "$ffmpeg $ffmpeg_codec_option 2>&1 |");
        while(<CHECK_CODECS>) {
            # tagging files with AtomicParsley using format mp4 or ipod makes it
            # give error below when trying to re-tag the file:
            #
            # AtomicParsley error: an atom was detected that presents as larger than filesize. Aborting.
            # atom free is 4294965313 bytes long which is greater than the filesize of 1164214
            #
            # error not displayed when using format psp oddly enough
            #
            if (/ .*EA.* libfaac/) {
                $acodec = "libfaac";
                $aac = 1;
            }
            if (/ .*EA.* aac/) {
                $acodec = "aac";
                $aac = 1;
            }
            if (/ .*EV.* h264/) {
                $vcodec = "h264";
                $h264 = 1;
            }
            if (/ .*EV.* libx264/) {
                $vcodec = "libx264";
                $h264 = 1;
            }
        }
        close(CHECK_CODECS);

        open(CHECK_FORMATS, "$ffmpeg -formats 2>&1 |");
        while(<CHECK_FORMATS>) {
            if (/ .*E.* ipod/) {
                $ipod_format_found = 1;
            }
            if (/ .*E.* psp/) {
                $psp_format_found = 1;
            }
        }
        close(CHECK_FORMATS);

        if ( $aac != 1 || $h264 != 1 ) {
            print STDERR "ERROR:\n";
            print STDERR "Your version of ffmpeg located at $ffmpeg doesn't support AAC audio or H264 video.\n";
            print STDERR "You need to upgrade your ffmpeg software.  I suggest updating via the latest SVN.\n";
            exit;
        }

        if ( $psp_format_found == 1 ) {
            # setting to format PSP basically just writes the PSP special title atom.
            $format = "psp";
        } elsif ( $ipod_format_found == 1 ) {
            # setting to format iPod basically just enforces you are using .m4v as an extension.
            # and somehow goofs up the atoms so you can't do a re-write with AtomicParsley
            # same deal with format mp4 (goofs atoms somehow)
            $format = "ipod";
        }

        # having to set refs now since we modify it for ipoddvd to 2
        # Will also modify it later if actual encode width and height = 640x480
        # black screen if you use refs 3 and dimensions are actually 640x480

        # coder
        # 0 = variable length coder / huffman
        # 1 = Arithmetic coder
        # if you want file in /VIDEO use 0 or 1
        # if you want file in /MP_ROOT/101ANV01 then use 1 only, won't play with 0 in /MP_ROOT/101ANV01
        #
        # ipod only supports 0, so if you are trying to make a more universal encode only use 0
        # * Entropy coders {name (n for -coder n)}: CAVLC (0), CABAC (1)
        # changed this to use the maxrate option also, noticed when I encoded family guy s06e01 without
        # this option it hiccuped at 2 places due to bitrate exceeding 3500kb/s

        if ( $opt{t} eq "ipod" ) {
            $psp_width = int($opt{W});
            $psp_height = int($psp_width/$video_aspect_ratio);
            # examintion of iTunes HD content is they use
            # High Profile 3.1
            # using dct8x8 activates High Profile
            $level = 31;
            # seems like a good number, i dunno
            #$vbitrate = "1664kb"; #128*13
            #$vbitrate = "1920kb"; #128*15
            #$vbitrate = "2176kb"; #128*17
            #$vbitrate = "2944kb"; #128*23
            #$vbitrate = "2350kb"; #128*18 for a 3hr movie, use this (you can't go over 4gb (fat 32 limitation for ps3's)
            $abitrate = "160k";
            # Apple HD uses refs 2 for some reason
            # need examine if refs 5 is bad for any reason
            # maybe plays better with 3 refs.  slightly larger encodes by a couple megabyte
            #$refs = 5;
            $refs = 3;
            #$refs = 2;
            # Apple has updated the firmware many times, don't try to stream with OS below 3.0.1
            # it is just terrible performance
            if ( $opt{I} ) {
                $coder = 1;
                # Post Grad still had a few problems streaming at 5000kb, slight errors
                # Trying lower setting to see if streaming can be perfected with it.
                #$coder_line = "-coder $coder -trellis 2 -maxrate 5000kb -bufsize 1000kb";
                #$coder_line = "-coder $coder -trellis 2 -maxrate 4960kb -bufsize 1034kb";
                # with a bufsize of ~1000 you will get slight errors occasionally, very rare
                # pixel problems on strange scenes, i can't explain.
                # dark_shikari said to raise buf to double as it was absurdly small.
                # I raise to 2k as suggested and problem go away
                # he says buf size needs to be at least half a second to be good
                #$coder_line = "-coder $coder -trellis 2 -maxrate 4960kb -bufsize 2000kb";
                # Only mess with this if you want it to NOT play on your Apple TV.
                $vbitrate = "768k"; #"1024k"; #128*23
                # Dont stream with this setting, Don't modify it either.
                $coder_line = "-coder $coder -trellis 2 -maxrate 4200k -bufsize 2100k $deinterlace";
                # $coder_line = "-coder $coder -trellis 2 -maxrate 2100k -bufsize 1050k $deinterlace";
                # 4300 still displayed very sight errors in Post Grad, during race event
                # not sure its worth to keep lowering more and more when they do play fine sycn'ed...
                # believe you will have to set this to at least 4000 if you want to stream 1280x720
                # and have ALL scenes play perfect, 4300 still displayed slow frame issues
                # during the Post Grad logo and following college scene minute
                # also displays errors during go cart race.  Those scenes still play at 5000
                # but the errors are more prominent.  These 2 sections out of 88 minutes isnt bad
                # alternative is to sync it and it plays without error at 5000 even might be able to go
                # as high as 7000 synced without errors, with no limits everything plays synced, but
                # some material does have the slow frame rate issue
                #$coder_line = "-coder $coder -trellis 2 -maxrate 4300kb -bufsize 1000kb";
            } else {
                $coder = 0;
                # This is tested and streams and plays perfectly at these settings
                # You could proabably raise that bitrate to 5000 if you wanted
                # and also use 10000/10000 according to HandBrake devs and Dark_Shikari
                # In the two example HD iTunes movies I have Apple is using
                # 3906kb for 1280x530 and 3869kb for 1280x540
                # So basically 128*30
                # They are also using 160kb AAC and 384kb DD which is 64kb less than 448kb, this doesn't matter though
                # you could use 640kb DD audio if you wanted as all it does is pass through
                #$vbitrate = "3904kb"; #(128*30)+64
                $vbitrate = "1536k"; #128*24
                #$vbitrate = "3072k"; #128*24
                #$vbitrate = "2890k"; #128*24
                $coder_line = "-coder $coder -maxrate 10000k -bufsize 5000k $deinterlace";
                $me_range_value = $appletv_cavlc_me_range_value;
            }
        } elsif ( $opt{t} eq "appletv" ) {
            $psp_width = int($opt{W});
            $psp_height = int($psp_width/$video_aspect_ratio);
            # examintion of iTunes HD content is they use
            # High Profile 3.1
            # using dct8x8 activates High Profile
            $level = 31;
            # seems like a good number, i dunno
            #$vbitrate = "1664kb"; #128*13
            #$vbitrate = "1920kb"; #128*15
            #$vbitrate = "2176kb"; #128*17
            #$vbitrate = "2944kb"; #128*23
            #$vbitrate = "2350kb"; #128*18 for a 3hr movie, use this (you can't go over 4gb (fat 32 limitation for ps3's)
            #$abitrate = "448k";
            $abitrate = "160k";
            # Apple HD uses refs 2 for some reason
            # need examine if refs 5 is bad for any reason
            # maybe plays better with 3 refs.  slightly larger encodes by a couple megabyte
            #$refs = 5;
            $refs = 3;
            #$refs = 2;
            # Apple has updated the firmware many times, don't try to stream with OS below 3.0.1
            # it is just terrible performance
            if ( $opt{I} ) {
                $coder = 1;
                # Post Grad still had a few problems streaming at 5000kb, slight errors
                # Trying lower setting to see if streaming can be perfected with it.
                #$coder_line = "-coder $coder -trellis 2 -maxrate 5000kb -bufsize 1000kb";
                #$coder_line = "-coder $coder -trellis 2 -maxrate 4960kb -bufsize 1034kb";
                # with a bufsize of ~1000 you will get slight errors occasionally, very rare
                # pixel problems on strange scenes, i can't explain.
                # dark_shikari said to raise buf to double as it was absurdly small.
                # I raise to 2k as suggested and problem go away
                # he says buf size needs to be at least half a second to be good
                #$coder_line = "-coder $coder -trellis 2 -maxrate 4960kb -bufsize 2000kb";
                # Only mess with this if you want it to NOT play on your Apple TV.
                $vbitrate = "1536k"; #128*23
                #$vbitrate = "1280"; #128*23
                # Dont stream with this setting, Don't modify it either.
                $coder_line = "-coder $coder -trellis 2 -maxrate 4200k -bufsize 2100k $deinterlace";
                # 4300 still displayed very sight errors in Post Grad, during race event
                # not sure its worth to keep lowering more and more when they do play fine sycn'ed...
                # believe you will have to set this to at least 4000 if you want to stream 1280x720
                # and have ALL scenes play perfect, 4300 still displayed slow frame issues
                # during the Post Grad logo and following college scene minute
                # also displays errors during go cart race.  Those scenes still play at 5000
                # but the errors are more prominent.  These 2 sections out of 88 minutes isnt bad
                # alternative is to sync it and it plays without error at 5000 even might be able to go
                # as high as 7000 synced without errors, with no limits everything plays synced, but
                # some material does have the slow frame rate issue
                #$coder_line = "-coder $coder -trellis 2 -maxrate 4300kb -bufsize 1000kb";
            } else {
                $coder = 0;
                # This is tested and streams and plays perfectly at these settings
                # You could proabably raise that bitrate to 5000 if you wanted
                # and also use 10000/10000 according to HandBrake devs and Dark_Shikari
                # In the two example HD iTunes movies I have Apple is using
                # 3906kb for 1280x530 and 3869kb for 1280x540
                # So basically 128*30
                # They are also using 160kb AAC and 384kb DD which is 64kb less than 448kb, this doesn't matter though
                # you could use 640kb DD audio if you wanted as all it does is pass through
                #$vbitrate = "3904k"; #(128*30)+64
                #$vbitrate = "2560k"; #128*20
                $vbitrate = "3072k"; #128*24
                #$vbitrate = "1536k"; #128*24
                #$vbitrate = "1024k"; #128*24
                #$vbitrate = "2975kb"; #128*24
                #$vbitrate = "2890kb"; #128*24
                $coder_line = "-coder $coder -maxrate 10000k -bufsize 5000k $deinterlace";
                $me_range_value = $appletv_cavlc_me_range_value;
            }
        } else {
            $psp_width = 640;
            $psp_height = 480;
            $level = 30;
            # video bit rate is subjective
            # I didn't see any pixelization at 640kb, but around words, like in intro
            # credits I did see some pixelization around those.  When cranked up to 1024
            # that went away.  For general usage you probably wont be able to tell much difference
            # between 640 and 1024.
            #$vbitrate = "640kb"; #32*20
            #$vbitrate = "768kb"; #32*24
            $vbitrate = "896k"; #128*7
            $abitrate = "128k";
            #$vbitrate = "1024kb"; #32*32
            $refs = 3;
            $coder = 0;
            #$coder_line = "-coder $coder -maxrate 1792kb -bufsize 768kb"; # plays fine, peaks of around 2500, plays ok
            #$coder_line = "-coder $coder -maxrate 1680kb -bufsize 840kb $deinterlace"; # plays fine, peaks of around 2500, plays ok
            $coder_line = "-coder $coder $deinterlace"; # plays fine, peaks of around 2500, plays ok
        }
        $extension = ".m4v";
    } elsif ( $opt{t} eq "psp" ) {
        print "Selected type: $opt{t}\n";
        $format = "mp4";
        open(CHECK_CODECS, "$ffmpeg $ffmpeg_codec_option 2>&1 |");
        while(<CHECK_CODECS>) {
            if (/ .*EA.* libfaac/) {
                $acodec = "libfaac";
                $aac = 1;
            }
            if (/ .*EA.* aac/) {
                $acodec = "aac";
                $aac = 1;
            }
            if (/ .*EV.* h264/) {
                $vcodec = "h264";
                $h264 = 1;
            }
            if (/ .*EV.* libx264/) {
                $vcodec = "libx264";
                $h264 = 1;
            }
        }
        close(CHECK_CODECS);

        open(CHECK_FORMATS, "$ffmpeg -formats 2>&1 |");
        while(<CHECK_FORMATS>) {
            if (/ .*E.* psp/) {
                $format = "psp";
            }
        }
        close(CHECK_FORMATS);

        if ( $aac != 1 || $h264 != 1 ) {
            print STDERR "ERROR:\n";
            print STDERR "Your version of ffmpeg located at $ffmpeg doesn't support AAC audio or H264 video.\n";
            print STDERR "You need to upgrade your ffmpeg software.  I suggest updating via the latest SVN.\n";
            exit;
        }

        $psp_width = 480;
        $psp_height = 272;
        $level = 21;
        # psp is ok with refs 3 for everything
        $refs = 3;

        # ipod compatible
        if ( $opt{i} ) {
            $coder = 0;
            $coder_line = "-coder $coder $deinterlace";
        } else {
            $coder = 1;
            $coder_line = "-coder $coder -trellis 2 $deinterlace";
        }

        # video filename extension
        #$extension = ".mp4";
        # changing extension to better support uShare on Linux
        # it defaults mp4 as audio file.
        $extension = ".m4v";

        # audio and video bitrates
        $vbitrate = "384k";
        $abitrate = "128k";
    } elsif ( $opt{t} =~ /^ipodwide$|^ipod480|^ipoddvd$|^ipodntscdvd$|^ipodpaldvd$|^psp480p$|^psp576p$|^psp640wide$/ ) {
        # of note, we could also do 640x480 with a 16/9 DAR.  I tested and it does work.
        # this would give us less pixel data though and thats bad ;-)
        print "Selected type: $opt{t}\n";
        $format = "mp4";
        open(CHECK_CODECS, "$ffmpeg $ffmpeg_codec_option 2>&1 |");
        while(<CHECK_CODECS>) {
            if (/ .*EA.* libfaac/) {
                $acodec = "libfaac";
                $aac = 1;
            }
            if (/ .*EA.* aac/) {
                $acodec = "aac";
                $aac = 1;
            }
            if (/ .*EV.* h264/) {
                $vcodec = "h264";
                $h264 = 1;
            }
            if (/ .*EV.* libx264/) {
                $vcodec = "libx264";
                $h264 = 1;
            }
        }
        close(CHECK_CODECS);

        open(CHECK_FORMATS, "$ffmpeg -formats 2>&1 |");
        while(<CHECK_FORMATS>) {
            if (/ .*E.* psp/) {
                $format = "psp";
            }
        }
        close(CHECK_FORMATS);

        if ( $aac != 1 || $h264 != 1 ) {
            print STDERR "ERROR:\n";
            print STDERR "Your version of ffmpeg located at $ffmpeg doesn't support AAC audio or H264 video.\n";
            print STDERR "You need to upgrade your ffmpeg software.  I suggest updating via the latest SVN.\n";
            exit;
        }

        # video filename extension
        #$extension = ".mp4";
        # changing extension to better support uShare on Linux
        # it defaults mp4 as audio file.
        $extension = ".m4v";

        # audio bitrate
        $abitrate = "128k"; # 32*4

        #default level
        $level = 30;
        # psp is ok with refs 3 for everything
        $refs = 3;

        # ipod anamorphic res above 640x480 can only use 1 or 2 refs
        # you will get a black screen if you use refs 3
        if ($opt{t} eq "psp480p") {
            $psp_width = 720;
            $psp_height = 480;
            $coder = 1;
            $coder_line = "-coder $coder -trellis 2 $deinterlace";
            #$vbitrate = "1024kb"; # 128*8
            $vbitrate = "1152k"; # 128*9
            #$vbitrate = "1408kb"; # 128*11
            $abitrate = "160k"; # 32*5
        } elsif ( $opt{t} eq "psp576p") {
            $psp_width = 720;
            $psp_height = 576;
            $coder = 1;
            $coder_line = "-coder $coder -trellis 2 $deinterlace";
            #$vbitrate = "1024kb"; # 128*8
            #$vbitrate = "1152kb"; # 128*9
            $vbitrate = "1280k"; # 128*10
            #$vbitrate = "1408kb"; # 128*11
            $abitrate = "160k"; # 32*5
        } elsif ( $opt{t} eq "psp640wide" ) {
            $psp_width = 640;
            $psp_height = 480;
            $coder = 1;
            $coder_line = "-coder $coder -trellis 2 $deinterlace";
            #$vbitrate = "896kb"; # 128*7
            $vbitrate = "1024k"; # 128*8
            $abitrate = "160k"; # 32*5
        } elsif ( $opt{t} eq "ipodpaldvd" ) {
            $psp_width = 720;
            $psp_height = 576;
            #$vbitrate = "1280kb"; # 128*10
            $vbitrate = "1408k"; # 128*11
            $abitrate = "160k"; # 32*5
            print "Setting frame rate to 25 fps\n";
            $rate = "-r 25/1";
            if ( $opt{I} ) {
                $coder = 1;
                $coder_line = "-coder $coder -trellis 2 -maxrate 4200k -bufsize 2100k $deinterlace";
                $refs = 3;
            } else {
                $coder = 0;
                $coder_line = "-coder $coder $deinterlace";
                $refs = 2;
            }
        } elsif ( $opt{t} eq "ipodntscdvd" ) {
            $psp_width = 720;
            $psp_height = 480;
            #$vbitrate = "1152kb"; # 128*9
            #$vbitrate = "1408kb"; # 128*11
            $vbitrate = "1280k"; # 128*10
            $abitrate = "160k"; # 32*5
            # opt I will not work on iPods, but ok for Apple TV
            # good for Apple TV to use -pbIH if encoding from DVD source
            if ( $opt{I} ) {
                $coder = 1;
                $coder_line = "-coder $coder -trellis 2 -maxrate 4200k -bufsize 2100k $deinterlace";
                $refs = 3;
            } else {
                $coder = 0;
                $coder_line = "-coder $coder $deinterlace";
                $refs = 2;
            }
        } elsif ( $opt{t} eq "ipoddvd" ) {
            $psp_width = 640;
            $psp_height = 480;
            $coder = 0;
            # http://www.apple.com/ipodclassic/specs.html
            # http://trac.handbrake.fr/wiki/VBVRateControl
            # bitrate limits are in place for iPod 5th gen.  Trouble with playback on certain material types otherwise
            #$coder_line = "-coder $coder -maxrate 1792kb -bufsize 768kb"; # plays fine, peaks of around 2500, plays ok
            #$coder_line = "-coder $coder -maxrate 1680kb -bufsize 840kb $deinterlace"; # plays fine, peaks of around 2500, plays ok
            $coder_line = "-coder $coder $deinterlace"; # plays fine, peaks of around 2500, plays ok
            # video bitrate is debatable.  I would need some hard proof
            # that higher than 896 ABR is necessary.  896 and 1024 look identical
            # from bluray source.
            #$vbitrate = "6144kb"; # 128*48 - bad stutter play
            #$vbitrate = "4096kb"; # 128*32 - had a stutter
            #$vbitrate = "3072kb"; # 128*24 - seemed ok
            #$vbitrate = "1408kb"; # <--- Apples rate.
            $vbitrate = "1024k"; # 128*8
            #$vbitrate = "992kb"; # 32*31
            #$vbitrate = "896kb"; # 128*7
            $abitrate = "160k"; # 32*5
            #$abitrate = "128kb"; # 32*5 <--- Apples rate.
            # do not modify refs below here ever, breaks ipod 5th gen playback for certain and that is what this profile is for
            $refs = 2;
        } elsif ( $opt{t} eq "ipod480" ) {
            $psp_width = 480;
            $psp_height = 320;
            $coder = 0;
            $coder_line = "-coder $coder $deinterlace";
            $vbitrate = "512k"; # 128*9
            #$vbitrate = "1408kb"; # 128*11
            $abitrate = "128k"; # 32*5
            $refs = 3;
            $level = 21;
        } else {
            $psp_width = 320;
            $psp_height = 240;
            $coder = 0;
            $coder_line = "-coder $coder $deinterlace";
            $vbitrate = "384k"; # 128*3
            $refs = 3;
            $level = 13;
        }

        # display aspect ratio
        $aspect = (16/9);
        # $aspect = (720/480); # 1.5, using this would yield a PAR of 1, and not stretch like we want it to since we are trying to make
        # 16/9 widescreen videos.

        # if we are encoding from an NTSC DVD
        # then don't do squat, otherwise ya we gotta monkey
        if ( $got_dvd == 1 && $opt{t} =~ /ipod/ && $opt{a} || $got_dvd == 1 && $opt{t} =~ /^psp480p$|^psp576p$|^psp640wide$/ ) {
            $psp_encode_width = $psp_width;
            $psp_encode_height = $psp_height;
            $crop_line = "";

            if ( $wide == 1 ) {
                $aspect = "16:9";
            } else {
                $aspect = "4:3";
            }

        } else {
            # pixel aspect ratio
            $par = (($psp_height*$aspect)/$psp_width); # 32/27

            print "video dimensions: ${width}x${height}\n";
            #print "video DAR: $video_aspect_ratio\n";
            print "16x9 DAR: $aspect\n";
            print "16x9 DAR on ${psp_width}x${psp_height} yields PAR: $par\n";

            # compute a new height
            $new_height = (($par*$psp_width)/$video_aspect_ratio);
            $int_new_height = int($new_height);

            if ( $int_new_height =~ /(1|3|5|7|9)$/ ) {
                $int_new_height++;
            }

            # check if height is greater than psp_height
            # if it then compute new width
            if ( $int_new_height > $psp_height) {
                print "This doesn't appear to be a widescreen source\n";

                $new_width = (($video_aspect_ratio*$psp_height)/$par);
                $int_new_width = int($new_width);

                if ( $int_new_width =~ /(1|3|5|7|9)$/ ) {
                    $int_new_width++;
                }

                $pad_horizontal = ($psp_width-${int_new_width});
                $padleft = ($pad_horizontal/2);
                $padright = $padleft;

                if ( $padleft =~ /(1|3|5|7|9)$/ ) {
                    $padleft++;
                    $padright--;
                }

                $psp_encode_width = $int_new_width;
                $psp_encode_height = $psp_height;

                print "new width is $psp_encode_width\n";
                print "pad horizontal is $pad_horizontal\n";
                print "new dimensions are ${psp_encode_width}x${psp_encode_height} with a horizontal padding of $pad_horizontal ($padleft left, $padright right)\n";

                $view_width = (($psp_encode_width+$pad_horizontal)*$par);
                $view_height = ($psp_encode_height);
                print "with PAR applied viewing dimensions will be: ${view_width}x${view_height}\n";
            } else {
                # height was good
                # figure out padding
                $pad_vertical = ($psp_height-${int_new_height});
                $padtop = ($pad_vertical/2);
                $padbottom = $padtop;

                if ( $padtop =~ /(1|3|5|7|9)$/ ) {
                    $padtop++;
                    $padbottom--;
                }

                $psp_encode_width = $psp_width;
                $psp_encode_height = $int_new_height;

                print "new height is $psp_encode_height\n";
                print "pad vertical is $pad_vertical\n";
                print "new dimensions are ${psp_encode_width}x${psp_encode_height} with a vertical padding of $pad_vertical ($padtop top, $padbottom bottom)\n";

                $view_width = ($psp_encode_width*$par);
                $view_height = ($psp_encode_height+$pad_vertical);
                print "with PAR applied viewing dimensions will be: ${view_width}x${view_height}\n";
            }

            # this is another hack
            # shouldn't even have this, should have the logic built in above to just not
            # even bother computing this data if type ipod style and not hard boxing
            # this is easier though...
            # oh well, least we use $view_width from it.
            if ( $pad_vertical > 0 && $opt{t} =~ /ipod/ && ! $opt{a}) {
                $padtop = 0;
                $padbottom = 0;
                $aspect = ($view_width/$psp_encode_height);
                print "iPod style encode, removing top and bottom padding\n";
                print "viewing dimensions will be ${view_width}x${psp_encode_height}\n";
                print "video aspect ratio will be $aspect\n";
            }
        }
        # we can't fall through the normal routines
        # call them via subroutines and then exit
        do_naming();
        do_encode_file();
        if ( $opt{M} ) {
            if ( $opt{Z} ) {
                print "Saving extracted audio.\n";
            } else {
                if ( $opt{n} ) {
                    print "deleting extracted audio file: $output_folder/$opt{n}.$audio_extension\n";
                    unlink "$output_folder/$opt{n}.$audio_extension";
                } else {
                    print "deleting extracted audio file: $output_folder/audio.$audio_extension\n";
                    unlink "$output_folder/audio.$audio_extension";
                }
            }
        }
        do_create_thumbnail();
        do_atomicparsley();
        exit;
    } elsif ( $opt{t} eq "pspavi" ) {
        print "Selected type: $opt{t}\n";
        $format = "avi";
        open(CHECK_CODECS, "$ffmpeg $ffmpeg_codec_option 2>&1 |");
        while(<CHECK_CODECS>) {
            if (/ .*EA.* pcm_s16le/) {
                # go!cam records audio in mono at 22050 Hz
                #$acodec = "pcm_s16le -ac 1 -ar 22050";
                # outputting to stereo and 48000 Hz
                $acodec = "pcm_s16le -ac 2 -ar 48000";
                # outputting to stereo and 22050 Hz
                #$acodec = "pcm_s16le -ac 2 -ar 22050";
                $pcm = 1;
            }
            if (/ .*EV.* mjpeg/) {
                $vcodec = "mjpeg";
                $mjpeg = 1;
            }
        }
        close(CHECK_CODECS);

        if ( $pcm != 1 || $mjpeg != 1 ) {
            print STDERR "ERROR:\n";
            print STDERR "Your version of ffmpeg located at $ffmpeg doesn't support PCM audio or MJPEG video.\n";
            print STDERR "You need to upgrade your ffmpeg software.  I suggest updating via the latest SVN.\n";
            exit;
        }

        $psp_width = 480;
        $psp_height = 272;

        # hardboxing all material as PSP only plays avi Motion JPG in 480x272
        $opt{a} = 1;

        # go!cam records at 30 FPS by default but we don't have to use that
        #$rate = "-r 30";

        # video filename extension
        $extension = ".avi";

        # video bitrate
        # flawless video requires around 6000kb/s
        #$vbitrate = "768kb";
        #$vbitrate = "1536kb";
        # still noticable blocky at 3072
        #$vbitrate = "3072kb";
        # seems ok
        $vbitrate = "4480k"; #140x32
        #$vbitrate = "6144kb"; #192x32
    } elsif ( $opt{t} =~ /^psp640$|^psp768$/ ) {
        print "Selected type: $opt{t}\n";
        $format = "mp4";
        open(CHECK_CODECS, "$ffmpeg $ffmpeg_codec_option 2>&1 |");
        while(<CHECK_CODECS>) {
            if (/ .*EA.* libfaac/) {
                $acodec = "libfaac";
                $aac = 1;
            }
            if (/ .*EA.* aac/) {
                $acodec = "aac";
                $aac = 1;
            }
            if (/ .*EV.* h264/) {
                $vcodec = "h264";
                $h264 = 1;
            }
            if (/ .*EV.* libx264/) {
                $vcodec = "libx264";
                $h264 = 1;
            }
        }
        close(CHECK_CODECS);

        open(CHECK_FORMATS, "$ffmpeg -formats 2>&1 |");
        while(<CHECK_FORMATS>) {
            if (/ .*E.* psp/) {
                $format = "psp";
            }
        }
        close(CHECK_FORMATS);

        if ( $aac != 1 || $h264 != 1 ) {
            print STDERR "ERROR:\n";
            print STDERR "Your version of ffmpeg located at $ffmpeg doesn't support AAC audio or H264 video.\n";
            print STDERR "You need to upgrade your ffmpeg software.  I suggest updating via the latest SVN.\n";
            exit;
        }

        # Hard boxing all material as it can only play 640x480, no shorter heights
        # though the video from cyber-shot is always 640x480 anyhow, but just in case
        # want to encode something else to 640x480 this will make it so
        $opt{a} = 1;

        if ( $opt{t} eq "psp640" ) {
            $psp_width = 640;
            $psp_height = 480;
            $vbitrate = "768k";
        } else {
            $psp_width = 768;
            $psp_height = 576;
            $vbitrate = "896k";
            $opt{x} = 1;
        }

        $level = 30;
        $refs = 3;

        # psp only supports 640x480 using CABAC
        $coder = 1;
        $coder_line = "-coder $coder -trellis 2 $deinterlace";

        $extension = ".m4v";
        $abitrate = "128k";
    } elsif ( $opt{t} eq "3g2" ) {
        print "Selected type: $opt{t}\n";
        $format = "3g2";
        open(CHECK_CODECS, "$ffmpeg $ffmpeg_codec_option 2>&1 |");
        while(<CHECK_CODECS>) {
            if (/ .*EA.* libfaac/) {
                $acodec = "libfaac";
                $aac = 1;
            }
            if (/ .*EA.* aac/) {
                $acodec = "aac";
                $aac = 1;
            }
            if (/ .*EV.* h263/) {
                $h263 = 1;
            }
            if (/ .*EV.* mpeg4/) {
                $mpeg4 = 1;
            }
            if (/ .*EV.* libxvid/) {
                $libxvid = 1;
            }
        }
        close(CHECK_CODECS);

        if ( $libxvid == 1 ) {
            $vcodec = "libxvid -flags +loop";
        } elsif ( $mpeg4 == 1 ) {
            $vcodec = "mpeg4 -flags +loop";
        } elsif ( $h263 == 1 ) {
            $vodec = "h263 -flags +loop";
        } else {
            print STDERR "ERROR:\n";
            print STDERR "No video codec for format $format found.  You need libxvid, mpeg4, or h263 video codecs.";
            print STDERR "You need to upgrade your ffmpeg software.  I suggest updating via the latest SVN.\n";
            exit;
        }

        if ( $aac != 1 ) {
            print STDERR "ERROR:\n";
            print STDERR "Your version of ffmpeg located at $ffmpeg doesn't support AAC audio.\n";
            print STDERR "You need to upgrade your ffmpeg software.  I suggest updating via the latest SVN.\n";
            exit;
        }

        # Hard boxing all material as it can only play 176x144 not 176x100 or whatever
        $opt{a} = 1;

        # cell phone 3g2 size
        $psp_width = 176;
        $psp_height = 144;

        # it defaults mp4 as audio file.
        $extension = ".3g2";

        # audio and video bitrates
        $vbitrate = "256k";
        $abitrate = "64k";
    } elsif ( $opt{t} eq "zune30" ) {
        open(CHECK_CODECS, "$ffmpeg $ffmpeg_codec_option 2>&1 |");
        while(<CHECK_CODECS>) {
            if (/ .*EA.* wmav2/){
                $wmav2 = 1;
                $acodec = "wmav2";
            }
            if (/ .*EV.* wmv2/){
                $wmv2 = 1;
                $vcodec = "wmv2";
            }
        }
        close(CHECK_CODECS);

        if ( $wmav2 != 1 || $wmv2 != 1 ) {
            print STDERR "ERROR:\n";
            print STDERR "Your version of ffmpeg located at $ffmpeg doesn't support Windows Media 8 encoding.\n";
            print STDERR "You can either update your ffmpeg to a newer release or use iPod encoding and let the Zune software trancode the format to a Windows Media format.\n";
            exit;
        }

        print "Selected type: $opt{t}\n";
        $psp_width = 320;
        $psp_height = 240;
        # not seeing any differences here when i select one of the other with Zune
        $coder = 0;
        #$coder = 1;

        # video filename extension
        $extension = ".wmv";

        # audio and video bitrates
        # the wmv2 video encoding is crap compared to h264/libx264
        # so I have raised the bitrate higher, even this doesn't look as good as the 384kb with h264
        # If you have choppyness and stuttering audio then you most likely have an old svn version
        # of ffmpeg.  Use 340kb video and 64kb audio and it should be acceptable then (or just upgrade).
        $vbitrate = "540k";
        $abitrate = "128k";
    } elsif ( $opt{t} eq "zune" ) {
        print STDERR "ERROR:\n";
        print STDERR "If you have a Zune 4GB, 8GB, or 80GB then use \"-t psp -i\" or use \"-t ipod\"\n";
        print STDERR "If you have a Zune 30GB then use -t zune30\n";
        exit;
    } else {
        print STDERR "ERROR: Invalid type: $opt{t}\n";
        exit;
    }
    # default encode dimension values
    $psp_encode_width = ($psp_width);
    $psp_encode_height = ($psp_height);

    # the psp is almost perfect 16:9 ratio, but it has 2 extra pixels of height
    $aspect = ($psp_width/$psp_height);
}

do_naming();
sub do_naming {
    # legacy psp naming
    if ( $opt{l} ) {
        if ( ! $opt{s} ) {
            print STDERR "ERROR: Legacy naming requires: [-s XXXXX]\n";
            exit;
        }
        if ( ! $opt{n} ) {
            print STDERR "ERROR: Legacy naming requires: [-n <PSP NAME>]\n";
            exit;
        }
        if ( $opt{t} ne "psp" ) {
            print STDERR "ERROR: Legacy naming requires [-t psp]\n";
            exit;
        }
        print "Selected naming: legacy\n";

            $output_file = "MAQ${sequence}$extension";
        $thumbnail_type = "MAQ${sequence}.thm";
        print "Selected thumbnail type: $thumbnail_type\n";

    } else {
        if ( $opt{n} ) {
                $output_file = "$opt{n}$extension";
                $thumbnail_type = "$opt{n}.jpg";
            print "Selected naming: modified title\n";
            print "Selected thumbnail type: $thumbnail_type\n";
        } else {

            print "Selected naming: simple\n";

            $output_file = (`basename \"$file\"`);
            chomp $output_file;
            $thumbnail_type = ($output_file);
            $output_file =~ s/\.\w+$/$extension/;
            $thumbnail_type =~ s/\.\w+$/\.jpg/;

            print "Selected thumbnail type: $thumbnail_type\n";
        }
    }
}

#$psp_encode_height = int($psp_width/$video_aspect_ratio);

if ($psp_encode_height > $psp_height) {
    print "video source appears to not be widescreen format.\n";

    # changing height to 270 to make a more perfect 4:3 AR
    if ( $opt{t} eq "psp" ) {
        $psp_height = 270;
        #$psp_height = 272;
    }

    #resetting height to default height screen size
    $psp_encode_height = ($psp_height);
    #print "psp encode height = $psp_encode_height\n";
    $psp_encode_width = int($psp_encode_height * $video_aspect_ratio);

    if ( $psp_encode_width =~ /(1|3|5|7|9)$/ ) {
        print "The psp_encode_width: $psp_encode_width is odd. Adjusting.\n";     # There is a remainder (of 1)
        $psp_encode_width++;
    }

    # calculate difference in width from screen size to encode size to maintain AR
    $psp_encode_width_difference = ($psp_width-$psp_encode_width);
    print "psp encode width difference = $psp_encode_width_difference\n";

    $padleft = ($psp_encode_width_difference/2);
    $padright = ($padleft);

    if ( $padleft =~ /(1|3|5|7|9)$/ ) {
            print "The padleft: $padleft is odd. Increasing value, decreasing padright.\n";
        $padleft++;
        $padright--;
    }
}

if ( $psp_encode_height =~ /(1|3|5|7|9)$/ ) {
    print "The psp_encode_height: $psp_encode_height is odd. Increasing value.\n";
    $psp_encode_height++;
}

print "psp video dimensions = ${psp_encode_width}x${psp_encode_height}\n";

$psp_aspect_ratio = ($psp_encode_width/$psp_encode_height);
print "psp video aspect ratio = $psp_aspect_ratio\n";

$psp_encode_height_difference = ($psp_height-$psp_encode_height);
print "psp video height difference = $psp_encode_height_difference pixels\n";

if ($psp_encode_height_difference == 2) {
    $padtop = 2;
} else {
    if ($psp_encode_height_difference > 0) {
        $padtop = ($psp_encode_height_difference/2);

        $padbottom = ($padtop);

        if ( $padtop =~ /(1|3|5|7|9)$/ ) {
            print "the padtop height $padtop is odd. Increasing value, decreasing padbottom.\n";
            $padtop++;
            $padbottom--;
        }
    }
}

# to lazy to re-write everything
# so any padding calculation done above is probably just a waste of time
# if option a isn't set then reset all padding and set the aspect to the aspect of the psp encoded video
if ( $opt{g} ) {
    print "Letterboxing video to next macro block\n";

    $padtop = 0;
    $padbottom = 0;
    $padleft = 0;
    $padright = 0;

    $video_height = $psp_encode_height;

        $block_ok = 0;

        while ( $block_ok == 0 ) {
                $block_size = ($video_height/16);
                if ($block_size =~ /^\d+$/) {
                        $block_ok = 1;
                } else {
                        $padtop++;
                        $video_height = ($psp_encode_height + $padtop);
                }
        }

        if ($padtop > 2) {
                $padtop = ( $padtop/2 );
                $padbottom = $padtop;
                if ( $padtop =~ /(1|3|5|7|9)$/ ) {
                        $padtop++;
                        $padbottom--;
                }
        }

        $aspect = ($psp_encode_width/$video_height);

    print "pad top = $padtop\n";
    print "pad bottom = $padbottom\n";
    print "new video frame is ${psp_encode_width}x${video_height}\n";
    print "new frame aspect ratio is $aspect\n";
}
elsif ( $opt{a} ) {
    print "Hard boxing video.\n";
    print "pad top = $padtop\n";
    print "pad bottom = $padbottom\n";
    print "pad left = $padleft\n";
    print "pad right = $padright\n";
    print "new frame aspect ratio is $aspect\n";
} else {
    $padtop = 0;
    $padbottom = 0;
    $padleft = 0;
    $padright = 0;
    $aspect = $psp_aspect_ratio
}

do_encode_file();

if ( $opt{M} ) {
    if ( $opt{Z} ) {
        print "Saving extracted audio.\n";
    } else {
        if ( $opt{n} ) {
            print "deleting extracted audio file: $output_folder/$opt{n}.$audio_extension\n";
            unlink "$output_folder/$opt{n}.$audio_extension";
        } else {
            print "deleting extracted audio file: $output_folder/audio.$audio_extension\n";
            unlink "$output_folder/audio.$audio_extension";
        }
    }
}

do_create_thumbnail();
do_atomicparsley();

sub do_encode_file {

    # checking ipod640 dimensions and changing refs from 3 to 2 if total size = 640x480
    if ( $opt{t} eq "ipod640" ) {
        $pad_horizontal = ($padleft + $padright);
        $pad_vertical = ($padtop + $padbottom);
        $total_width = ($psp_encode_width + $pad_horizontal);
        $total_height = ($psp_encode_height + $pad_vertical);

        if ( $total_width == 640 && $total_height == 480) {
            $refs = 2;
        }
    }

    # check to see if we have the new metadata ffmpeg option
    if ( $meta_data == 1 ) {
        $title_string = "-metadata title=\"$title\"";
    } else {
        $title_string = "-title \"$title\"";
    }

    if ($stik eq "Music Video" && $opt{t} eq "psp") {
        $vbitrate = "768k"; #32*24
        $abitrate = "160k";
    }

    print "encoding file: $file\n";

    print "output file = $output_file\n";

    # these use auto rate (just copies rate from source)
    # if for some reason this starts to fail you could use
    # -r 30000/1001 (29.97 fps) tv
    # -r 24000/1001 (23.976 fps) film
    # I believe hardcoding a rate will get around the bug below found in quicktime/ipod
    # "a bad public movie atom was found in the movie"

    # manipulate ffmpeg
    $original_ffmpeg = "$ffmpeg -y";
    $ffmpeg = "$original_ffmpeg";

    while ( $pass < $loops ) {
        # increment pass variable
        $pass++;

        if ( $loops == 2 ) {
            $pass_string = "-pass $pass";
            if ( $pass == 1 ) {
                if ( $opt{M} ) {
                    $audio_string = "-acodec $acodec -ab $abitrate -ac 2 -ar 48000";
                } else {
                    $audio_string = "-acodec $acodec -ab $abitrate -ac 2 $vol -ar 48000";
                }
                $original_subq_value = $subq;
                $original_refs_value = $refs;
                $me_method_value = "dia";
                $subq = "-subq 2";
                $refs = 1;
                $original_me_range_value = $me_range_value;
                $me_range_value = $default_me_range_value;
            } else {
                if ( $opt{M} ) {
                    print "Preparing for 2 pass encode with piped audio.\n";
                    extract_matroska_audio();

                    # Some goofy MKV files do not have the video track as track 0, so this works around that
                    $audio_string = "-map 1.$video_track -map 0.0 -acodec $acodec -ab $abitrate -ac 2 -ar 48000";

                    if ( $dts == 1 ) {
                        if ( $opt{n} ) {
                            if ( $opt{S} ) {
                                $ffmpeg = "$dcadec $gain -o wav \"$output_folder/$opt{n}.$audio_extension\" | $original_ffmpeg -i -";
                            } else {
                                #attempting to create Dolby Pro Logic streams.  dcadec errors if you use -o wavdolby!!
                                $ffmpeg = "$original_ffmpeg -i \"$output_folder/$opt{n}.$audio_extension\" -ab 640k -f ac3 - | $a52dec $gain -o wavdolby | $original_ffmpeg -i -";
                            }
                        } else {
                            if ( $opt{S} ) {
                                $ffmpeg = "$dcadec $gain -o wav \"$output_folder/audio.$audio_extension\" | $original_ffmpeg -i -";
                            } else {
                                #attempting to create Dolby Pro Logic streams.  dcadec errors if you use -o wavdolby!!
                                $ffmpeg = "$original_ffmpeg -i \"$output_folder/audio.$audio_extension\" -ab 640k -f ac3 - | $a52dec $gain -o wavdolby | $original_ffmpeg -i -";
                            }
                        }
                    } else {
                        if ( $opt{n} ) {
                            if ( $opt{S} ) {
                                $ffmpeg = "$a52dec $gain -o wav \"$output_folder/$opt{n}.$audio_extension\" | $original_ffmpeg -i -";
                            } else {
                                #changed from wav to wavdolby to create Dolby Pro Logic stream
                                $ffmpeg = "$a52dec $gain -o wavdolby \"$output_folder/$opt{n}.$audio_extension\" | $original_ffmpeg -i -";
                            }
                        } else {
                            if ( $opt{S} ) {
                                $ffmpeg = "$a52dec $gain -o wav \"$output_folder/audio.$audio_extension\" | $original_ffmpeg -i -";
                            } else {
                                #changed from wav to wavdolby to create Dolby Pro Logic stream
                                $ffmpeg = "$a52dec $gain -o wavdolby \"$output_folder/audio.$audio_extension\" | $original_ffmpeg -i -";
                            }
                        }
                    }
                } else {
                    $audio_string = "-acodec $acodec -ab $abitrate -ac 2 $vol -ar 48000";
                }
                $me_method_value = "umh";
                $subq = $original_subq_value;
                $refs = $original_refs_value;
                $me_range_value = $original_me_range_value;
            }
        } else {
            if ( $opt{M} ) {
                print "Preparing for 1 pass encode with piped audio.\n";
                extract_matroska_audio();

                # Some goofy MKV files do not have the video track as track 0, so this works around that
                $audio_string = "-map 1.$video_track -map 0.0 -acodec $acodec -ab $abitrate -ac 2 -ar 48000";

                if ( $dts == 1 ) {
                    if ( $opt{n} ) {
                        if ( $opt{S} ) {
                            $ffmpeg = "$dcadec $gain -o wav \"$output_folder/$opt{n}.$audio_extension\" | $original_ffmpeg -i -";
                        } else {
                            #attempting to create Dolby Pro Logic streams.  dcadec errors if you use -o wavdolby!!
                            $ffmpeg = "$original_ffmpeg -i \"$output_folder/$opt{n}.$audio_extension\" -ab 640k -f ac3 - | $a52dec $gain -o wavdolby | $original_ffmpeg -i -";
                        }
                    } else {
                        if ( $opt{S} ) {
                            $ffmpeg = "$dcadec $gain -o wav \"$output_folder/audio.$audio_extension\" | $original_ffmpeg -i -";
                        } else {
                            #attempting to create Dolby Pro Logic streams.  dcadec errors if you use -o wavdolby!!
                            $ffmpeg = "$original_ffmpeg -i \"$output_folder/audio.$audio_extension\" -ab 640k -f ac3 - | $a52dec $gain -o wavdolby | $original_ffmpeg -i -";
                        }
                    }
                } else {
                    if ( $opt{n} ) {
                        if ( $opt{S} ) {
                            $ffmpeg = "$a52dec $gain -o wav \"$output_folder/$opt{n}.$audio_extension\" | $original_ffmpeg -i -";
                        } else {
                            #changed from wav to wavdolby to create Dolby Pro Logic stream
                            $ffmpeg = "$a52dec $gain -o wavdolby \"$output_folder/$opt{n}.$audio_extension\" | $original_ffmpeg -i -";
                        }
                    } else {
                        if ( $opt{S} ) {
                            $ffmpeg = "$a52dec $gain -o wav \"$output_folder/audio.$audio_extension\" | $original_ffmpeg -i -";
                        } else {
                            #changed from wav to wavdolby to create Dolby Pro Logic stream
                            $ffmpeg = "$a52dec $gain -o wavdolby \"$output_folder/audio.$audio_extension\" | $original_ffmpeg -i -";
                        }
                    }
                }
            } else {
                $audio_string = "-acodec $acodec -ab $abitrate -ac 2 $vol -ar 48000";
            }
            $me_method_value = "umh";
        }

        if ($copy_audio_settings == 1 ) {
            $audio_string = "-acodec $acodec $vol";
        }

        #$audio_string = "-acodec $acodec";
        #$audio_string = "-acodec $acodec -ab $abitrate -ac 2 $vol";
        #$audio_string = "-acodec copy";
        #$audio_string = "-map 0:0 -map 1:11 -acodec $acodec -ab $abitrate -ac 2 $vol -ar 48000";
        #$audio_string = "-map 0:0 -map 0:6 -acodec $acodec -ab $abitrate -ac 2 $vol -ar 48000";

        # A couple map examples for DVD's
        #
        # Not another Teen Movie DVD
                #$audio_string = "-map 0.$video_track -map 0.4 -acodec $acodec -ab $abitrate -ac 2 -ar 48000 -alang $audio_lang";
        # Tommy Boy DVD & Cop Out DVD & Despicable Me
        #$audio_string = "-map 0.$video_track -map 0.2 -acodec $acodec -ab $abitrate -ac 2 -ar 48000 -alang $audio_lang";


        if ($opt{t} =~ /psp640|psp768/ && $opt{x}) {
            $psp_encode_width = 720;
            if ( $opt{t} eq "psp640" ) {
                $psp_encode_height = 480;
            } else {
                $psp_encode_height = 576;
            }
            # removing pad amounts because they will be added back in at encode time
            $psp_encode_width = $psp_encode_width-${padleft};
            $psp_encode_width = $psp_encode_width-${padright};
            $psp_encode_height = $psp_encode_height-${padtop};
            $psp_encode_height = $psp_encode_height-${padbottom};
        }

        if ( $opt{t} eq "zune30" ) {
            `$ffmpeg -i \"$file\" $crop_line $audio_string -vcodec $vcodec -aspect $aspect -b:v $vbitrate -flags +loop -coder $coder -s ${psp_encode_width}x${psp_encode_height} -padtop $padtop -padbottom $padbottom -padleft $padleft -padright $padright $title_string $time $start_time $pass_string $threads_line \"$output_folder\"/\"$output_file\"`;
        } elsif ( $opt{t} eq "3g2" ) {
                `$ffmpeg -i \"$file\" $crop_line $audio_string -vcodec $vcodec -aspect $aspect -b:v $vbitrate $rate -s ${psp_encode_width}x${psp_encode_height} -padtop $padtop -padbottom $padbottom -padleft $padleft -padright $padright $title_string -f $format -g 250 -keyint_min 25 $time $start_time $pass_string $threads_line \"$output_folder\"/\"$output_file\"`;
        } elsif ( $opt{t} eq "pspavi" ) {
                `$ffmpeg -i \"$file\" $crop_line -acodec $acodec -vcodec $vcodec -aspect $aspect -b:v $vbitrate $rate -s ${psp_encode_width}x${psp_encode_height} -padtop $padtop -padbottom $padbottom -padleft $padleft -padright $padright $title_string -f $format $time $start_time $pass_string $threads_line \"$output_folder\"/\"$output_file\"`;
        } else {
            # -rq_eq appears to control the -qmin and -qmax parameters.  it seems to adjust them based on some formula in the string value.
            # the default -qmin is 2 and the default -qmax is 31.  The higher the -qmax the more blockier it is.
            # if you dont use the -rq_eq it appears to default to just using the -qmax, though it does fluxuate a little, but not much.
            # here is a qmin test web page.  Lower the qmin the bigger the file and more clear it is.
            # http://forum.videohelp.com/topic264848.html
            # and this page maps the ffmpeg flags to x264 flags (I took this guys suggestions)
            # http://ffmpeg.x264.googlepages.com/mapping
            # using -rq_eq will make it so that you have a bigger file, this is because it will be normally using a lower -q setting, my testing of hd tv shows
            # had it using a q setting of around 20.  Encoding family guy cartoon it was even lower, like 16 sometimes.
            # if you dont like these larger files then get rid of the -rq_eq and hard code it like the above statement, where it will just use -qmin 2 -qmax 31 (the default)
            #
            # this plays on psp, +dct8x8 does not work at all, using +bpyramid causes video corruption, more than 3 references frames and wont play either
            # -bf 3 is blu ray standard (bframes 3).  This plays below fine on psp and computer, but on xbmc fast forward or rewind is messed up
            # waits until it gets an I frame I believe to correct itself or a scene change
            # ipod encode string, no b frames
            #`$ffmpeg -i \"$file\" -acodec copy -vcodec copy $title_string -f $format \"$output_folder\"/\"$output_file\"`;
            #`$ffmpeg -i \"$file\" $crop_line $audio_string -vcodec $vcodec -level $level -aspect $aspect -b:v $vbitrate $rate $coder_line -s ${psp_encode_width}x${psp_encode_height} $vlang -padtop $padtop -padbottom $padbottom -padleft $padleft -padright $padright $title_string -f $format -cmp +chroma -flags +loop -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -deblockalpha 0 -deblockbeta 0 -refs $refs -sc_threshold 40 $bflags -qdiff 4 -qcomp 0.60 -complexityblur 20.0 -qblur 0.5 -g 250 -keyint_min 25 $subq -me_range $me_range_value $me_method $me_method_value -qmin 10 -qmax 51 -i_qfactor 0.71 -rc_eq 'blurCplx^(1-qComp)' $wpredp $time $start_time $pass_string $threads_line \"$output_folder\"/\"$output_file\"`;
            `$ffmpeg -i \"$file\" $crop_line $audio_string -vcodec $vcodec -level $level -aspect $aspect -b:v $vbitrate $rate $coder_line -s ${psp_encode_width}x${psp_encode_height} $vlang $title_string -f $format -cmp +chroma -flags +loop -partitions +parti4x4+parti8x8+partp4x4+partp8x8+partb8x8 -refs $refs -sc_threshold 40 $bflags -qdiff 4 -qcomp 0.60 -g 250 -keyint_min 25 $subq -me_range $me_range_value $me_method $me_method_value -qmin 10 -strict -2 -qmax 51 -i_qfactor 0.71 -rc_eq 'blurCplx^(1-qComp)' $wpredp $time $start_time $pass_string $threads_line \"$output_folder\"/\"$output_file\"`;
        }
    }
}

sub do_create_thumbnail {
    #$ffmpeg = $original_ffmpeg;
    #if ( $opt{t} eq "psp" || $opt{t} eq "psp480p" || $opt{t} eq "psp576p" || $opt{t} eq "psp640wide" || $opt{t} eq "ipod" || $opt{t} eq "psp640" || $opt{t} eq "psp768" ) {
    #   print "Generating thumbnail for PSP.\n";
    #   $thumb_height = int(160/$video_aspect_ratio);
    #   $padtop = 0;
    #   $padbottom = 0;
    #
    #   if ( $thumb_height < 120 ) {
    #       if ( $thumb_height =~ /(1|3|5|7|9)$/ ) {
    #           print "Thumbnail height of $thumb_height is odd, decreasing value.\n";
    #           $thumb_height--;
    #       }
    #
    #       print "thumb height is $thumb_height\n";
    #
    #       $thumb_height_difference = (120 - $thumb_height);
    #       print "thumb padding amount = $thumb_height_difference\n";
    #
    #       $padtop = ($thumb_height_difference/2);
    #       $padbottom = ($padtop);
    #
    #       if ( $padtop =~ /(1|3|5|7|9)$/ ) {
    #               print "The thumb padtop: $padtop is odd. Increasing value, decreasing padbottom.\n";
    #           $padtop++;
    #           $padbottom--;
    #       }
    #
    #
    #       print "thumb pad top = $padtop\n";
    #       print "thumb pad bottom = $padbottom\n";
    #   }
    #
    #   `$ffmpeg -i \"$file\" $thumb_crop_line -f image2 -ss $thumbtime -vframes 1 -s 160x${thumb_height} -padtop $padtop -padbottom $padbottom -aspect 4:3 -an \"$output_folder\"/\"$thumbnail_type\"`;
    #
    #   if ( $jhead_found == 1 ) {
    #       print "Removing comment from PSP thumbnail to generate a proper JPEG header.\n";
    #       `$jhead -dc \"$output_folder\"/\"$thumbnail_type\"`;
    #   }
    #}
}

sub do_atomicparsley {
    if ( $atomicparsley_found == 1 && $opt{t} ne "pspavi" ) {

        #hopefully geID is always populated no matter what with something
        if ( $got_geid == 1 ) {
            $geid_write = "--geID $geID";
        }

        if ( $opt{N} ) {
            #print "PSP title is $title\n";
            $title = $opt{N};
            if ( $title =~ /\"/ ) {
                #print "AtomicParsley title is $opt{N}\n";
                $title =~ s/\"/\\"/g;
                #print "escaped AtomicParsley title is $title\n";
            }
        }

        # handle Poster Art
        if ( $opt{C} ) {
            # AtomicParsley complains if jpgs have comment on them
            # I guess some applications put a comment on jpeg
            if ( $jhead_found == 1 && $poster_art_type =~ /(jpg)/i) {
                print "Copying poster art $poster_art to temp location.\n";
                `cp \"$poster_art\" \"$output_folder\"/temp_poster_art.jpg`;
                print "Removing comments from temp poster art.\n";
                `$jhead -dc \"$output_folder/temp_poster_art.jpg\"`;
                $artwork = "--artwork \"$output_folder\"/temp_poster_art.jpg";
            } else {
                $artwork = "--artwork \"$poster_art\"";
            }
        }

        if ( $description =~ /\"/ ) {
            $description =~ s/\"/\\"/g;
        }

        if ( $long_description =~ /\"/ ) {
            $long_description =~ s/\"/\\"/g;
        }

        if ( $got_long_description ) {
            $long_description_string = "$longdesc \"$long_description\"";
        }

        if ( $opt{t} eq "psp" && $coder == 0 || $opt{t} eq "ipod640" || $opt{t} eq "ipoddvd" || $opt{t} eq "ipod480") {
            print "Setting iPod 5g high res iTunes atom\n";
            $ipodatom = "--DeepScan --iPod-uuid 1200"
        } else {
            $ipodatom = "";
        }

            if ( $opt{t} eq "psp" || $opt{t} eq "psp480p" || $opt{t} eq "psp576p" || $opt{t} eq "psp640wide" || $opt{t} eq "ipod" || $opt{t} eq "psp640" || $opt{t} eq "psp768" || $opt{t} eq "ipod640" || $opt{t} eq "ipoddvd" || $opt{t} eq "ipod480" || $opt{t} eq "ipodwide" || $opt{t} eq "ipodntscdvd" || $opt{t} eq "ipodpaldvd" || $opt{t} eq "appletv") {
            print "Setting iTunes atoms\n";
            if ( $stik eq "TV Show" ) {
                `$atomicparsley \"$output_folder\"/\"$output_file\" $ipodatom --TVShowName \"$tvshowname\" --TVEpisode \"$tvepisode\" --description \"$description\" $long_description_string --TVSeasonNum $tvseasonnum --TVEpisodeNum $tvepisodenum --encodingTool \"$encodingtool\" --title \"$title\" --artist \"$artist\" --album \"$album\" --year $itunes_year --comment \"$comment\" --purchaseDate \"$purchasedate\" --stik \"$stik\" --copyright \"$copyright\" $contentRating --rDNSatom \'$iTunMOVI_data\' name=iTunMOVI domain=com.apple.iTunes $genre $tracknum $hdvideo $apid $encodedby $cnid $geid_write $artwork --overWrite`;
            } elsif ( $stik eq "Music Video" ) {
                `$atomicparsley \"$output_folder\"/\"$output_file\" $ipodatom --description \"$description\" $long_description_string --encodingTool \"$encodingtool\" --title \"$title\" --artist \"$artist\" --album \"$album\" --year $itunes_year --comment \"$comment\" --purchaseDate \"$purchasedate\" --stik \"$stik\" --copyright \"$copyright\" --rDNSatom \'$iTunMOVI_data\' name=iTunMOVI domain=com.apple.iTunes $genre $hdvideo $apid $encodedby $cnid $geid_write $artwork --overWrite`;
            } else {
                `$atomicparsley \"$output_folder\"/\"$output_file\" $ipodatom --description \"$description\" $long_description_string --encodingTool \"$encodingtool\" --title \"$title\" --artist \"$artist\" --album \"$album\" --year $itunes_year --comment \"$comment\" --purchaseDate \"$purchasedate\" --stik \"$stik\" --copyright \"$copyright\" $contentRating --rDNSatom \'$iTunMOVI_data\' name=iTunMOVI domain=com.apple.iTunes $genre $hdvideo $apid $encodedby $cnid $geid_write $artwork --overWrite`;
            }

            if ($opt{C} && $jhead_found == 1 && $poster_art_type =~ /(jpg)/i) {
                print "Deleting temporary poster art.\n";
                unlink "$output_folder/temp_poster_art.jpg";
            }
            }

            if ( $opt{t} eq "3g2" ) {
            print "Setting 3g2 atoms\n";
            if ( $stik eq "Music Video" ) {
                # description, title, author appear to show up in quicktime inspector, --3gp-performer doesn't
                `$atomicparsley \"$output_folder\"/\"$output_file\" --3gp-description \"$description\" --3gp-title \"$title\" --3gp-author \"$artist\" --3gp-album \"$album\" --3gp-year $year $genre --overWrite`;
            } else {
                `$atomicparsley \"$output_folder\"/\"$output_file\" --3gp-description \"$description\" --3gp-title \"$title\" --3gp-author \"$artist\" --3gp-album \"$album\" --3gp-year $year $genre --overWrite`;
            }
        }

        print "Displaying AtomicParsley text data\n";

        open(ATOMICTEXT, "$atomicparsley \"$output_folder\"/\"$output_file\" --textdata |") or die "Cannot open file: $!";
        while(<ATOMICTEXT>) {
            print;
        }
        close(ATOMICTEXT);
    }
}

sub extract_matroska_audio {
    # figure out track to pull and determine AC3 or DTS
    open(MKVINFO, "$mkvmerge -i \"$file\" |");
    while(<MKVINFO>) {
        if ( /Track ID (\d): audio \(A_DTS\)/ ) {
            print "Extracting track $1 which is a DTS audio track\n";
            $track = $1;
            $dts = 1;
            $audio_extension = "dts";
            last;
        }
        if ( /Track ID (\d): audio \(A_AC3\)/ ) {
            print "Extracting track $1 which is a AC3 audio track\n";
            $track = $1;
            $dts = 0;
            $audio_extension = "ac3";
            last;
        }
    }
    close(MKVINFO);

    # extract audio track
    if ( $opt{n} ) {
        `$mkvextract tracks \"$file\" $track:\"$output_folder/$opt{n}.$audio_extension\"`;
        if ( $create_dd_track == 1 ) {
            if ( $opt{t} =~ /($create_dd_type_list)/ ) {
                if ( $audio_extension eq "dts" ) {
                    print "Creating ${dd_bitrate}k Dolby Digital audio track\n";
                    `$original_ffmpeg -i \"$output_folder/$opt{n}.$audio_extension\" -ab ${dd_bitrate}k $time \"$output_folder/$opt{n}-${dd_bitrate}k.ac3\"`;
                } else {
                    # we extracted a DD track
                    # see if it matches the target bitrate or needs to be reduced
                    open(CHECK_DD, "$original_ffmpeg -i \"$output_folder/$opt{n}.$audio_extension\" 2>&1 |");
                    while(<CHECK_DD>) {
                        #Stream #0.0: Audio: ac3, 48000 Hz, 5.1, s16, 384 kb/s
                        if (/Stream #0.0: Audio: ac3.+ (\d+) k\/s/) {
                            $dd_original_bitrate = $1;
                        }
                    }
                    close(CHECK_DD);

                    # process Dolby Digital original file
                    if ( $dd_original_bitrate > $dd_bitrate ) {
                        print "Creating ${dd_bitrate}k Dolby Digital audio track\n";
                        #reduce its bitrate
                        `$original_ffmpeg -i \"$output_folder/$opt{n}.$audio_extension\" -ab ${dd_bitrate}k $time \"$output_folder/$opt{n}-${dd_bitrate}k.ac3\"`;
                    } elsif ( $dd_original_bitrate <= $dd_bitrate ) {
                        # if original bitrate is less than or equal to target bitrate
                        # then just save the ac3 file
                        print "Saving ${dd_original_bitrate}k Dolby Digital audio track\n";
                        $opt{Z} = 1;
                    }
                }
            }
        }
    } else {
        `$mkvextract tracks \"$file\" $track:\"$output_folder/audio.$audio_extension\"`;
        if ( $create_dd_track == 1 ) {
            if ( $opt{t} =~ /($create_dd_type_list)/ ) {
                if ( $audio_extension eq "dts" ) {
                    print "Creating ${dd_bitrate}k Dolby Digital audio track\n";
                    `$original_ffmpeg -i \"$output_folder/audio.$audio_extension\" -ab ${dd_bitrate}k $time \"$output_folder/audio-${dd_bitrate}k.ac3\"`;
                } else {
                    # we extracted a DD track
                    # see if it matches the target bitrate or needs to be reduced
                    open(CHECK_DD, "$original_ffmpeg -i \"$output_folder/audio.$audio_extension\" 2>&1 |");
                    while(<CHECK_DD>) {
                        #Stream #0.0: Audio: ac3, 48000 Hz, 5.1, s16, 384 kb/s
                        if (/Stream #0.0: Audio: ac3.+ (\d+) k\/s/) {
                        $dd_original_bitrate = $1;
                        }
                    }
                    close(CHECK_DD);

                    # process Dolby Digital original file
                    if ( $dd_original_bitrate > $dd_bitrate ) {
                        print "Creating ${dd_bitrate}k Dolby Digital audio track\n";
                        #reduce its bitrate
                        `$original_ffmpeg -i \"$output_folder/audio.$audio_extension\" -ab ${dd_bitrate}k $time \"$output_folder/audio-${dd_bitrate}k.ac3\"`;
                    } elsif ( $dd_original_bitrate <= $dd_bitrate ) {
                        # if original bitrate is less than or equal to target bitrate
                        # then just save the ac3 file
                        print "Saving ${dd_original_bitrate}k Dolby Digital audio track\n";
                        $opt{Z} = 1;
                    }
                }
            }
        }
    }
}

sub get_date {
    if ($_[0] eq "gmtime") {
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($unix_time);
    } else {
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($unix_time);
    }
    $stringday = (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
    $stringmonth = (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];

    # year has 1900 substracted from it, so add it back.
    $year += 1900;
    # month is 0-11 range, so add 1 to it.
    $mon += 1;
    # week day is 0-6 range, so add 1 to it.
    $wday +=1;

    # prefixing a 0 to dates or numbers that are single digit
    $sec =~ s/^([0-9])$/0$1/;
    $min =~ s/^([0-9])$/0$1/;
    $hour =~ s/^([0-9])$/0$1/;
    $mon =~ s/^([0-9])$/0$1/;
    $mday =~ s/^([0-9])$/0$1/;

    $date = "$stringday $stringmonth $mday $hour:$min:$sec $year";
}

#### legacy x264 & ffmpeg info ####

#old x264 info:
  #-m, --subme <integer>       Subpixel motion estimation and partition
                                  #decision quality: 1=fast, 7=best. [6]
      #--b-rdo                 RD based mode decision for B-frames. Requires subme 6.
      #--bime                  Jointly optimize both MVs in B-frames

#old ffmpeg info (brdo option isn't in newer ffmpeg):
   #brdo                    E.V.. b-frame rate-distortion optimization
#-bidir_refine      <int>   E.V.. refine the two motion vectors used in bidirectional macroblocks

#new x264 info:
  #-m, --subme <integer>       Subpixel motion estimation and mode decision [6]
                                  #- 0: fullpel only (not recommended)
                                  #- 1: SAD mode decision, one qpel iteration
                                  #- 2: SATD mode decision
                                  #- 3-5: Progressively more qpel
                                  #- 6: RD mode decision for I/P-frames
                                  #- 7: RD mode decision for all frames
                                  #- 8: RD refinement for I/P-frames
                                  #- 9: RD refinement for all frames
#notes:
#weightp adds 2 ref frames *not tested anything with weightp*
#apparently iphone supports cabac and b frames and up to 6 refs *to do*
#investigate mbtree *enabled*
#implement new psp PAL res *DONE*

#look into incorporating
#http://code.google.com/p/mp4v2/

#Believe gives you the ability to modify
#trak.udta.name
#which is what subler and handbrake are doing to set unique names for Subtitle and Audio Tracks

#http://code.google.com/p/mp4v2/issues/detail?id=9
#http://code.google.com/p/mp4v2/source/detail?r=191
#http://code.google.com/p/mp4v2/source/detail?r=194
#you can see it is possible to set here
#http://mp4v2.googlecode.com/svn/doc/1.9.0/ToolGuide.html

#`--udtaname STR'
    #set trak.udta.name.value. Specifies an arbitrary track-name. This value is optional (may be absent).
#`--udtaname-remove'
    #remove trak.udta.name atom. This action will remove the optional atom.

# so appears we can use MP4Box to add the tracks
#MP4Box -add m-district9-720p.srt:lang=eng:layout=0x60x0x-1:group=2:hdlr="sbtl:tx3g" District 9.mp4
#MP4Box -add District 9.srt:lang=eng:layout=0x60x0x-1:group=2:hdlr="sbtl:tx3g":disable District 9.mp4
#and then can use mp4v2 to modify the atom so we can have unique names and have 2 of the same language to enable
#playback on Apple TV
# although mp4v2 may be able to add these tracks as well have to research that as well.

# Apple Quicktime Dolby Digital 5.1 pass through information
#
# http://developer.apple.com/mac/library/qa/qa2008/qa1604.html
# http://support.apple.com/kb/HT1755
# http://support.apple.com/kb/TA25199
# http://manuals.info.apple.com/en_US/Compressor_3_User_Manual.pdf
#
# subler creates these just fine.  I would make sure to label one track Stereo and the other Dolby Digital or Surround

# still unsure about aac 5.1 all of my tests the audio is right channeled, although I haven't tried eac3to
# tried various documents using mplayer and faac and all sound the same, doesn't appear to order channels correctly

# fix -ss, dark_shikari said to move -ss to infront of -i if I want to scan to the location immediately and not parse the file
# tried it, works, but audio sync is broken when doing this.

# check if passed genre type is valid for Short Film or TV Show

# search example for action & adventure tv category
#http://itunes.apple.com/us/genre/tv-shows-comedy/id4003
#itms://itunes.apple.com/WebObjects/MZStore.woa/wa/viewGenre?cc=us&id=4003&ign-mscache=1

sub genreIDs {
    %geIDMovie = (
        "Action & Adventure" => '4401',
        "Anime" => '4402',
        "Classics" => '4403',
        "Comedy" => '4404',
        "Documentary" => '4405',
        "Drama" => '4406',
        "Foreign" => '4407',
        "Horror" => '4408',
        "Independent" => '4409',
        "Kids & Family" => '4410',
        "Musicals" => '4411',
        "Romance" => '4412',
        "Sci-Fi & Fantasy" => '4413',
        "Short Films" => '4414',
        "Special Interest" => '4415',
        "Thriller" => '4416',
        "Sports" => '4417',
        "Western" => '4418',
        "Urban" => '4419',
        "Holiday" => '4420',
        "Made for TV" => '4421',
        "Concert Films" => '4422',
        "Music Documentaries" => '4423',
        "Music Feature Films" => '4424',
        "Japanese Cinema" => '4425',
        "Jidaigeki" => '4426',
        "Tokusatsu" => '4427',
        "Korean Cinema" => '4428',
    );

    %geIDTV = (
        "Comedy" => '4000',
        "Drama" => '4001',
        "Animation" => '4002',
        "Action & Adventure" => '4003',
        "Classic" => '4004',
        "Kids" => '4005',
        "Nonfiction" => '4006',
        "Reality TV" => '4007',
        "Sci-Fi & Fantasy" => '4008',
        "Sports" => '4009',
        "Teens" => '4010',
        "Latino TV" => '4011',
    );

    %geIDmvid = (
        "Blues" => '1602',
        "Comedy" => '1603',
        "Children's Music" => '1604',
        "Classical" => '1605',
        "Country" => '1606',
        "Electronic" => '1607',
        "Holiday" => '1608',
        "Opera" => '1609',
        "Singer/Songwriter" => '1610',
        "Jazz" => '1611',
        "Latino" => '1612',
        "New Age" => '1613',
        "Pop" => '1614',
        "R&B/Soul" => '1615',
        "Soundtrack" => '1616',
        "Dance" => '1617',
        "Hip Hop/Rap" => '1618',
        "World" => '1619',
        "Alternative" => '1620',
        "Rock" => '1621',
        "Christian & Gospel" => '1622',
        "Vocal" => '1623',
        "Reggae" => '1624',
        "Easy Listening" => '1625',
        "Podcasts" => '1626',
        "J-Pop" => '1627',
        "Enka" => '1628',
        "Anime" => '1629',
        "Kayokyoku" => '1630',
        "Disney" => '1631',
        "French Pop" => '1632',
        "German Pop" => '1633',
        "German Folk" => '1634',
    );
}

