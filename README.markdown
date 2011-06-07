# Just Pics
## Really simple image hosting.

Your own personal TwitPic, on Heroku & S3.

It's designed to be simple and highly cacheable. All images are served with long expiry times,
and as all URLs are based on the SHA of the image, their content should never change.

## Prerequisites

* An Amazon S3 Bucket

## Setup

    git clone git@github.com:cwninja/justpics.git
    cd justpics
    heroku create
    git push heroku
    heroku config:add \
      AMAZON_ACCESS_KEY_ID=YourAmazonAccessKeyId \
      AMAZON_SECRET_ACCESS_KEY=YourAmazonAccessKey \
      AMAZON_S3_BUCKET=YourAmazonS3BucketName \
      JUSTPICS_MINIMUM_KEY_LENGTH=6 \
      JUSTPICS_POST_PATH=/
    heroku open

You can then configure the Heroku app with a custom domain as per usual. If you wan't shorter URLs or a custom (secret) upload path, just tweak the Heroku config.

## iPhone Twitter Client Setup

In the advanced settings, simply change your image service to your upload URL (in the example setup above it's the root of your app).

## Costs

You should only be billed for the storage costs, as all access in and out of S3 is via the Heroku app, which is hosted inside the AWS platform.

This seems to be how it's worked out for me, your costs may vary, keep an eye on your bill.

## Licence
Copyright Tom Lea. Licensed under the [WTFBPPL][WTFBPPL].

[WTFBPPL]: http://tomlea.co.uk/WTFBPPL.txt
