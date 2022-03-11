#! /usr/bin/env python3

import xml.etree.ElementTree as et
import sys
import os

# Arguments
paths = sys.argv[1]
out   = sys.argv[2]

# Session options
genome    = 'hg38'
version   = '8'
height    = '561'
width     = '1131'
col       = '0,0,178'
gene_h    = '35'
font_size = '10'

# Paths
with open(paths) as f:
    paths = f.read().splitlines()[1:]

# Session options
sess = et.Element('Session')

sess.set('genome', genome)
sess.set('hasGeneTrack', 'true')
sess.set('hasSequenceTrack', 'true')
sess.set('locus', 'All')
sess.set('path', out)
sess.set('version', version)

# Add Resources
resources = et.SubElement(sess, 'Resources')

# Panel options
panel = et.SubElement(sess, 'Panel')
panel.set('height', height)
panel.set('name', 'DataPanel')
panel.set('width', width)

# Add sequence track
seq = et.SubElement(panel, 'Track')
seq.set('clazz', 'org.broad.igv.track.SequenceTrack')
seq.set('fontSize', font_size)
seq.set('id', 'Reference sequence')
seq.set('name', 'Reference sequence')
seq.set('visible', 'true')

# Add gene track
genes = et.SubElement(panel, 'Track')
genes.set('clazz', 'org.broad.igv.track.FeatureTrack')
genes.set('color', col)
genes.set('colorscale', 'ContinuousColorScale;0.0;845.0;255,255,255;0,0,178')
genes.set('fontSize', font_size)
genes.set('height', gene_h)
genes.set('id', 'hg38_genes')
genes.set('name', 'Gene')
genes.set('visible', 'true')

# Add data tracks
for line in paths:
    line = line.split()
    p    = line[0]
    nm   = os.path.basename(p)

    res = et.SubElement(resources, 'Resource')
    res.set('path', p)

    track = et.SubElement(panel, 'Track')
    track.set('autoScale', 'true')
    track.set('clazz', 'org.broad.igv.track.DataSourceTrack')
    track.set('fontSize', font_size)
    track.set('id', p)
    track.set('name', nm)
    track.set('renderer', 'BAR_CHART')
    track.set('visible', 'true')
    track.set('windowFunction', 'mean')
    track.set('color', col)

# Add track attributes
#atts = et.SubElement(sess, 'HiddenAttributes')
#nms = ['DATA FILE', 'DATA TYPE', 'NAME']
#for nm in nms:
#    att = et.SubElement(atts, 'Attribute')
#    att.set('name', nm)

# Write xml
out = os.path.abspath(out)
xml = et.tostring(sess)

with open(out, 'wb') as f:
    f.write(xml)

