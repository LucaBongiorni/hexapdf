# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2017 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#++

module HexaPDF

  # == Overview
  #
  # A *font loader* is a callable object that loads a font based on the given name and options. If
  # the font loader doesn't have the requested font, it has to return +nil+.
  #
  # The returned object has to be a PDF font wrapper and not the generic font object because it
  # needs to be usable by the PDF canvas. See below for details.
  #
  #
  # == Implementation of a Font Loader
  #
  # Each font loader is a (stateless) object (normally a module) that has to be callable, i.e. it
  # has to provide the following method:
  #
  # call(document, name, **options)::
  #     Should return the font wrapper customized for the given document if the font is known or
  #     else +nil+.
  #
  # The +options+ argument is font loader dependent. However, all font loaders should handle the
  # following common options:
  #
  # variant:: The font variant that should be used (e.g. +:none+, +:bold+, +:italic+,
  #           +:bold_italic+).
  #
  #
  # == Font Wrappers
  #
  # A font wrapper needs to provide the following generic interface so that it can be used correctly
  # by HexaPDF:
  #
  # dict::
  #     This method needs to return the PDF font dictionary that represents the wrapped font.
  #
  # decode_utf8(str)::
  #     This method needs to convert the given string into an array of glyph objects. The glyph
  #     objects themselves are treated as opaque objects by HexaPDF::Content::Canvas.
  #
  # encode(glyph)::
  #     This method takes a single glyph object, that needs to be compatible with the font wrapper,
  #     and returns an encoded string that can be decoded with the font dictionary returned by
  #     \#dict.
  #
  module FontLoader

    autoload(:Standard14, 'hexapdf/font_loader/standard14')
    autoload(:FromConfiguration, 'hexapdf/font_loader/from_configuration')

  end

end
