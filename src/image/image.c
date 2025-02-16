#define STBI_WRITE_NO_STDIO
#define STB_IMAGE_WRITE_STATIC
#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STB_IMAGE_IMPLEMENTATION
#define STBI_NO_LINEAR
#define STBI_NO_STDIO
#define STBI_NO_SIMD
#define STBI_NO_HDR

#include "stb_image.h"
#include "stb_image_write.h"

int main() { return 0; }

STBIDEF stbi_uc* image_load_gif_from_memory(stbi_uc const* buffer, int len,
    int** delays, int* x, int* y,
    int* z)
{
    int comp;
    return stbi_load_gif_from_memory(buffer, len, delays, x, y, z, &comp, 4);
}

/* dither.c: MIT License

Copyright (c) 2016 jonmortiboy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

typedef struct RGB {
    int r;
    int g;
    int b;
} RGB;

int imgw, imgh;

// Define the 4bit colour palette
int numCols = 16;
RGB cols4bit[] = {
    { 0, 0, 0 }, { 0, 0, 170 }, { 0, 170, 0 }, { 0, 170, 170 },
    { 170, 0, 0 }, { 170, 0, 170 }, { 170, 85, 0 }, { 170, 170, 170 },
    { 85, 85, 85 }, { 85, 85, 255 }, { 85, 255, 85 }, { 85, 255, 255 },
    { 255, 85, 85 }, { 255, 85, 255 }, { 255, 255, 85 }, { 255, 255, 255 }
};
RGB* cols = cols4bit;

RGB getRGB(uint32_t* pixels, int x, int y);
void setRGB(uint32_t* pixels, int x, int y, RGB rgb);
RGB difRGB(RGB from, RGB to);
RGB addRGB(RGB a, RGB b);
RGB divRGB(RGB rgb, double d);
RGB mulRGB(RGB rgb, double d);
RGB nearestRGB(RGB rgb, RGB* rgbs, int numRGBs);
double distRGB(RGB from, RGB to);

void render_4bit_floydstein(uint32_t* pixels, int width, int height);

RGB getRGB(uint32_t* pixels, int x, int y)
{
    RGB rgb;
    rgb.r = 0;
    rgb.g = 0;
    rgb.b = 0;

    if (x < 0 || x >= imgw || y < 0 || y >= imgh)
        return rgb;

    rgb.r = (pixels[y * imgw + x] & 0xff);
    rgb.g = (pixels[y * imgw + x] & 0xff00) >> 8;
    rgb.b = (pixels[y * imgw + x] & 0xff0000) >> 16;

    return rgb;
}

void setRGB(uint32_t* pixels, int x, int y, RGB rgb)
{
    if (x < 0 || x >= imgw || y < 0 || y >= imgh)
        return;

    uint32_t alpha = pixels[y * imgw + x] & 0xff000000;
    pixels[y * imgw + x] = alpha + (rgb.r) + (rgb.g << 8) + (rgb.b << 16);
}

RGB difRGB(RGB from, RGB to)
{
    RGB dif;
    dif.r = to.r - from.r;
    dif.g = to.g - from.g;
    dif.b = to.b - from.b;

    return dif;
}

RGB addRGB(RGB a, RGB b)
{
    RGB sum;
    sum.r = a.r + b.r;
    sum.g = a.g + b.g;
    sum.b = a.b + b.b;

    if (sum.r > 255)
        sum.r = 255;
    if (sum.r < 0)
        sum.r = 0;
    if (sum.g > 255)
        sum.g = 255;
    if (sum.g < 0)
        sum.g = 0;
    if (sum.b > 255)
        sum.b = 255;
    if (sum.b < 0)
        sum.b = 0;

    return sum;
}

RGB divRGB(RGB rgb, double d)
{
    RGB div;
    div.r = (int)((double)rgb.r / d);
    div.g = (int)((double)rgb.g / d);
    div.b = (int)((double)rgb.b / d);

    return div;
}

RGB mulRGB(RGB rgb, double d)
{
    RGB mul;
    mul.r = (int)((double)rgb.r * d);
    mul.g = (int)((double)rgb.g * d);
    mul.b = (int)((double)rgb.b * d);

    return mul;
}

double distRGB(RGB from, RGB to)
{
    RGB dif = difRGB(from, to);
    double dist = dif.r * dif.r + dif.g * dif.g + dif.b * dif.b;

    return dist;
}

RGB nearestRGB(RGB rgb, RGB rgbs[], int numRGBs)
{
    double dist = -1, tempDist;
    RGB nearest;

    int i;
    for (i = 0; i < numRGBs; i++) {
        tempDist = distRGB(rgb, rgbs[i]);

        if (tempDist < dist || dist < 0) {
            dist = tempDist;
            nearest = rgbs[i];
        }
    }

    return nearest;
}

void render_4bit_floydstein(uint32_t* pixels, int width, int height)
{

    int i, x, y;
    imgw = width;
    imgh = height;
    RGB rgb, nearest, rgberror;
    for (i = 0; i < imgw * imgh; i++) {
        rgb = getRGB(pixels, i % imgw, i / imgw);
        nearest = nearestRGB(rgb, cols, numCols);

        rgberror = difRGB(nearest, rgb);
        rgberror = divRGB(rgberror, 16);

        x = i % imgw;
        y = i / imgw;

        setRGB(pixels, x + 1, y,
            addRGB(getRGB(pixels, x + 1, y), mulRGB(rgberror, 7)));
        setRGB(pixels, x - 1, y + 1,
            addRGB(getRGB(pixels, x - 1, y + 1), mulRGB(rgberror, 3)));
        setRGB(pixels, x, y + 1,
            addRGB(getRGB(pixels, x, y + 1), mulRGB(rgberror, 5)));
        setRGB(pixels, x + 1, y + 1,
            addRGB(getRGB(pixels, x + 1, y + 1), rgberror));

        setRGB(pixels, i % imgw, i / imgw, nearest);
    }
}