FROM perl:5.8.9-threaded

RUN cpan -i Tk
RUN cpanm Graph@0.20105
RUN cpanm Statistics::Basic@0.41.3
RUN cpanm Statistics::Descriptive@2.6

WORKDIR /app 
COPY igen /app/

RUN mkdir mounted

CMD [ "perl", "igen-gui.pl"]
