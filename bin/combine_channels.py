#!/usr/bin/env python

'''
Module      : combine_channels
Description : Combine multiple channels into a single TIF
Copyright   : (c) WEHI SODA Hub, 2024
License     : MIT
Maintainer  : Marek Cmero
Portability : POSIX
'''
import os
import sys
import dask.array as da
from tifffile import TiffWriter
from aicsimageio import AICSImage

from argparse import ArgumentParser


def parse_args():
    '''Parse arguments'''
    description = '''
        Parse command line arguments.
        '''
    parser = ArgumentParser(description=description)
    parser.add_argument('-i',
                        '--images',
                        type=str,
                        required=True,
                        help='Input directory containing TIFF files.')
    parser.add_argument('-c',
                        '--channels',
                        type=str,
                        required=True,
                        help='Comma-separated list of input channels to merge.'
                        )
    parser.add_argument('-n',
                        '--name',
                        type=str,
                        default='mosaic_Cellbound_z',
                        help='''
                        Name of combined channel
                        (default = mosaic_Cellbound_z).
                        ''')
    parser.add_argument('-z',
                        '--zindex',
                        type=int,
                        default=4,
                        help='Z-index of the channel to extract (default = 4).'
                        )
    parser.add_argument('-o',
                        '--outdir',
                        type=str,
                        default='.',
                        help='Output directory. Current directory by default.')
    parser.add_argument('-r',
                        '--regex',
                        default='mosaic_(?P<stain>[\\w|-]+)_z(?P<z>[0-9]+).tif',
                        help='Image regex.')
    parser.add_argument('-d',
                        '--convert-dapi',
                        action='store_true',
                        help='Convert DAPI channel to single-channel TIFF.')
    parser.add_argument('-w',
                        '--overwrite',
                        action='store_true',
                        help='Overwrite existing files.')
    parser.add_argument('-t',
                        '--tile-size',
                        type=int,
                        default=512,
                        help="Size of tile in image.")
    parser.add_argument('-m',
                        '--microns-per-pixel',
                        type=float,
                        default=0.108,
                        help="Microns per pixel value.")
    return parser.parse_args()


def save_tif(img_combined, save_path, idx, img_name, tile_size,
             microns_per_pixel, overwrite=False):
    '''
    Save combined image as a single-channel TIF
    '''
    img_combined = img_combined.compute()
    output_file = os.path.join(save_path, f"{img_name}{idx}.tif")

    if os.path.exists(output_file) and not overwrite:
        print(f"WARNING: output file {output_file} exists. Not overwriting.")
        return

    with TiffWriter(output_file, bigtiff=True) as tif:
        options = dict(
           # tile=(tile_size, tile_size),
           compression='none',
           photometric='minisblack',
           metadata={'axes': 'YX',
                     'PhysicalSizeX': microns_per_pixel,
                     'PhysicalSizeY': microns_per_pixel},
           rowsperstrip=img_combined.shape[0]
        )
        tif.write(img_combined, **options)


def get_tifs(images, channels, z_string):
    '''
    Get image tif files corresponding to channels and z_strings
    Return one list of the channels to combine and the dapi file
    corresponding the the given z_string
    '''

    combine_tifs = []
    dapi_tif = []
    for item in os.listdir(images):
        file = os.path.join(images, item)
        if not os.path.isfile(file):
            continue
        for channel in channels:
            if channel in item.lower() and z_string in item.lower():
                combine_tifs.append(file)
        if 'dapi' in file.lower() and z_string in item.lower():
            dapi_tif.append(file)

    return combine_tifs, dapi_tif


def main():
    '''
    Main function
    '''
    args = parse_args()

    if not os.path.exists(args.images):
        print('Image directory does not exist.')
        sys.exit(1)

    if not os.path.exists(args.outdir):
        print('Output directory does not exist; creating...')
        os.makedirs(args.outdir)

    channels = args.channels.lower().split(',')
    idx = args.zindex
    z_string = f"z{idx:d}"

    combine_tifs, dapi_tif = get_tifs(args.images, channels, z_string)

    if args.convert_dapi:
        assert len(dapi_tif) == 1, "Found multiple DAPI files for z-index"

        dapi_tif = dapi_tif[0]
        print(f"Processing {os.path.basename(dapi_tif)}...")
        dapi_img = da.squeeze(AICSImage(dapi_tif).dask_data)

        save_tif(dapi_img, args.outdir, idx, 'mosaic_DAPI_z',
                 args.tile_size, args.microns_per_pixel,
                 args.overwrite)

    print('Combining channels...')
    channels_to_combine = []
    for tif in combine_tifs:
        print(f"Squeezing {os.path.basename(tif)}...")
        img = da.squeeze(AICSImage(tif).dask_data)
        channels_to_combine.append(img)

    if len(channels_to_combine) == 0:
        print('No channel files found, nothing to merge...')
        sys.exit(1)

    # take max of channels
    channel_max = da.maximum(*channels_to_combine)
    save_tif(channel_max, args.outdir, idx, args.name, args.tile_size,
             args.microns_per_pixel, args.overwrite)


if __name__ == '__main__':
    main()
