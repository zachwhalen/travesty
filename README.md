# A Travesty Generator for Micros

In 1984, Hugh Kenner and Joseph O'Rourke published [an article in _Byte_ Magazine](https://archive.org/details/byte-magazine-1984-11/page/n129) presenting a computer program for generating literary "travesties" or parodic versions of literary texts. Their code, written in Pascal, produces text such that the statistical distribution of any n-length string of characters is the same in the output as it was in the original text.

The article concludes with the source code of their program, which I've transcribed here.

To run this program, you'll need a Pascal compiler. On a Mac, I used [Free Pascal](https://www.freepascal.org/) which can be installed with home brew like so:

```
$ brew install fpc
```

To compile the Travesty program, run `fpc` in the same directory as the `travesty.pas` file:

```
$ fpc travesty.pas
```

If compilation is successful, you'll get two new files: `travesty.o` and `travesty`. The file simply called `travesty` is the executable binary, which you can run directly:

```
$ ./travesty
```

Before you do that, though, you should have a plain text file in the same directory ready to process. 