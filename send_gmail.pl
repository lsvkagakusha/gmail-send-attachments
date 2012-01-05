#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Net::SMTP::SSL;
use MIME::Base64;
use File::Spec;
use LWP::MediaTypes;

my $recepients;
my $subject;
my $body;
my $attachments;
my $help;

GetOptions(
    "recepients=s"  => \$recepients,
    'subject=s'     => \$subject,
    'body=s'        => \$body,
    'attachments=s' => \$attachments,
    'help|?'        => \$help,
  ) or pod2usage(2);

pod2usage(1) if $help;

die"Use -h, -? or --help!\n $!" unless $subject;

# Send away!
&send_mail_with_attachments( $recepients,
  $subject, 
  $body,
  $attachments
);



sub send_mail_with_attachments {

 my $to = shift(@_);
 my $subject = shift(@_);
 my $body = shift(@_);
 my $attach = shift(@_);
 my @attachments = split(/,/, $attach);
 my $from = 'my@mail.com';
 my $password = 'my_password';

 my $smtp;

 unless ( $smtp = Net::SMTP::SSL->new('smtp.gmail.com',
                              Port => 465,
                              Debug => 1)) {
     die "Could not connect to server\n";
 }

 # Authenticate
 $smtp->auth($from, $password)
     	|| die "Authentication failed!\n";

 # Create arbitrary boundary text used to seperate
 # different parts of the message
 my ($bi, $bn, @bchrs);
 my $boundry = "";
 foreach $bn (48..57,65..90,97..122) {
     $bchrs[$bi++] = chr($bn);
 }
 foreach $bn (0..20) {
     $boundry .= $bchrs[rand($bi)];
 }

 # Send the header
 $smtp->mail($from . "\n");
 my @recepients = split(/,/, $to);
 foreach my $recp (@recepients) {
     $smtp->to($recp . "\n");
 }
 $smtp->data();
 $smtp->datasend("From: " . $from . "\n");
 $smtp->datasend("To: " . $to . "\n");
 $smtp->datasend("Subject: " . $subject . "\n");
 $smtp->datasend("MIME-Version: 1.0\n");
 $smtp->datasend("Content-Type: multipart/mixed; BOUNDARY=\"$boundry\"\n");

 # Send the body
 $smtp->datasend("\n--$boundry\n");
 $smtp->datasend("Content-Type: text/plain\n");
 $smtp->datasend($body . "\n\n");

 # Send attachments
 foreach my $file (@attachments) {
     unless (-f $file) {
         die "Unable to find attachment file $file\n";
         next;
     }
     my($bytesread, $buffer, $data, $total);
     open(FH, "$file") || die "Failed to open $file\n";
     binmode(FH);
     while (($bytesread = sysread(FH, $buffer, 1024)) == 1024) {
         $total += $bytesread;
         $data .= $buffer;
     }
     if ($bytesread) {
         $data .= $buffer;
         $total += $bytesread;
     }
     close FH;

     # Get the file name without its directory
     my ($volume, $dir, $fileName) = File::Spec->splitpath($file);
  
     # Try and guess the MIME type from the file extension so
     # that the email client doesn't have to
     my $contentType = guess_media_type($file);
  
     if ($data) {
         $smtp->datasend("--$boundry\n");
         $smtp->datasend("Content-Type: $contentType; name=\"$fileName\"\n");
         $smtp->datasend("Content-Transfer-Encoding: base64\n");
         $smtp->datasend("Content-Disposition: attachment; =filename=\"$fileName\"\n\n");
         $smtp->datasend(encode_base64($data));
         $smtp->datasend("--$boundry\n");
     }
 }

 # Quit
 $smtp->datasend("\n--$boundry--\n"); # send boundary end message
 $smtp->datasend("\n");
 $smtp->dataend();
 $smtp->quit;
}



__END__

=head1 NAME

send_mail.pl - send mail with attachments using gmail account

=head1 SYNOPSIS

send_mail.pl [options] parameters

    
    --help        show this help message
    --recepients  rec1@mail.com,rec2@mail.com,...
    --subject     Subject(without spaces)
    --body        Message text(without spaces)
    --attachments attachm1,attachm2 ...

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--recepients>

Comma separated recepinents' Emails.

=item B<--subject>

Subject of message to all recepients without space characters.
All words after space are cutted.

=item B<--body>

Body of message without space characters.
All words after space are cutted.

=item B<--attachments>

Comma separated paths' to attachment files.

=back

=head1 DESCRIPTION

Bsend_mail.pl recepient1,recepient2... , subject, body, attachm1,attachm2...

=cut

