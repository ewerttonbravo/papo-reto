# Third-party notices

Papo Reto is MIT-licensed (see `LICENSE`). The app bundles the components below; their licenses follow. On macOS, this file and the two it names are in `PapoReto.app/Contents/Resources`; on Windows, they sit next to `PapoReto.exe`, with the .NET runtime's `dotnet-LICENSE.txt` and `dotnet-THIRD-PARTY-NOTICES.txt`.

| Component | Version | License | Source |
|---|---|---|---|
| sherpa-onnx (`libsherpa-onnx-c-api.dylib`, `sherpa-onnx-c-api.dll`, `sherpa-onnx.dll`) | 2.0.1 | Apache-2.0, text in `sherpa-onnx-LICENSE.txt` | https://github.com/k2-fsa/sherpa-onnx |
| kaldi-native-fbank, built into sherpa-onnx | 1.22.4 | Apache-2.0 | https://github.com/csukuangfj/kaldi-native-fbank |
| kaldi-decoder, built into sherpa-onnx | 0.3.0 | Apache-2.0 | https://github.com/k2-fsa/kaldi-decoder |
| kaldifst, built into kaldi-decoder | 1.8.0 | Apache-2.0 | https://github.com/k2-fsa/kaldifst |
| OpenFst, built into sherpa-onnx | 1.8.5-2026-07-09 | Apache-2.0, Copyright 2005-2026 Google LLC. | https://github.com/csukuangfj/openfst |
| simple-sentencepiece, built into sherpa-onnx | 0.7 | Apache-2.0 | https://github.com/pkufool/simple-sentencepiece |
| nlohmann/json, built into sherpa-onnx | 3.12.0 | MIT | https://github.com/nlohmann/json |
| utf8proc, built into sherpa-onnx | 2.12.0 | MIT and Unicode data license | https://github.com/JuliaStrings/utf8proc |
| hclust-cpp (fastcluster), built into sherpa-onnx | 2026-02-25 | BSD-2-Clause | https://github.com/csukuangfj/hclust-cpp |
| Eigen, built into sherpa-onnx | 5.0.1 | MPL-2.0; source at the link | https://gitlab.com/libeigen/eigen/-/archive/5.0.1/eigen-5.0.1.tar.gz |
| ONNX Runtime (`libonnxruntime.dylib`, `onnxruntime.dll`) | 1.28.2 | MIT; its own third-party notices in `onnxruntime-ThirdPartyNotices.txt` | https://github.com/csukuangfj/onnxruntime-libs/releases/tag/v1.28.2 |
| Silero VAD (`silero_vad.onnx`) | from sherpa-onnx's `asr-models` release | MIT | https://github.com/snakers4/silero-vad |
| .NET runtime and Windows Forms, Windows only | 10.0 | MIT; the runtime's third-party notices in `dotnet-THIRD-PARTY-NOTICES.txt` (Windows Forms ships none) | https://github.com/dotnet/runtime, https://github.com/dotnet/winforms |
| NAudio (`NAudio.Core.dll`, `NAudio.Wasapi.dll`), Windows only | 2.2.1 | MIT | https://github.com/naudio/NAudio |

## Speech model, downloaded on first launch (not in the app)
"Parakeet TDT 0.6B v3" by NVIDIA, licensed under CC-BY-4.0 (https://creativecommons.org/licenses/by/4.0/), from https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3. Papo Reto downloads the int8 ONNX export made by the sherpa-onnx project (https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8), a modification of the original model. It is provided as-is, without warranties, as the license states.

## MIT License
Applies to:
- ONNX Runtime: Copyright (c) Microsoft Corporation
- .NET runtime and Windows Forms: Copyright (c) .NET Foundation and Contributors
- NAudio: © Mark Heath 2023
- Silero VAD: Copyright (c) 2020-present Silero Team
- nlohmann/json: Copyright (c) 2013-2025 Niels Lohmann
- utf8proc: Copyright © 2014-2021 by Steven G. Johnson, Jiahao Chen, Tony Kelman, Jonas Fonseca, and other contributors listed in the git history; Copyright (c) 2009, 2013 Public Software Group e. V., Berlin, Germany

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

## Unicode data license (utf8proc)
COPYRIGHT AND PERMISSION NOTICE

Copyright (c) 1991-2007 Unicode, Inc. All rights reserved. Distributed
under the Terms of Use in http://www.unicode.org/copyright.html.

Permission is hereby granted, free of charge, to any person obtaining a
copy of the Unicode data files and any associated documentation (the "Data
Files") or Unicode software and any associated documentation (the
"Software") to deal in the Data Files or Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, and/or sell copies of the Data Files or Software, and
to permit persons to whom the Data Files or Software are furnished to do
so, provided that (a) the above copyright notice(s) and this permission
notice appear with all copies of the Data Files or Software, (b) both the
above copyright notice(s) and this permission notice appear in associated
documentation, and (c) there is clear notice in each modified Data File or
in the Software as well as in the documentation associated with the Data
File(s) or Software that the data or software has been modified.

THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
THIRD PARTY RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS
INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR
CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THE DATA FILES OR SOFTWARE.

Except as contained in this notice, the name of a copyright holder shall
not be used in advertising or otherwise to promote the sale, use or other
dealings in these Data Files or Software without prior written
authorization of the copyright holder.

## BSD-2-Clause (hclust-cpp)
Copyright:
  * fastcluster_dm.cpp & fastcluster_R_dm.cpp:
     © 2011 Daniel Müllner <http://danifold.net>
  * fastcluster.(h|cpp) & demo.cpp & plotresult.r:
     © 2018 Christoph Dalitz <http://www.hsnr.de/ipattern/>
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Mozilla Public License 2.0 (Eigen)
Eigen is under the MPL-2.0, https://www.mozilla.org/MPL/2.0/. Its unmodified source code is available at the Eigen link in the table above.

## Apache License 2.0
sherpa-onnx, kaldi-native-fbank, kaldi-decoder, kaldifst, OpenFst and simple-sentencepiece are licensed under the Apache License, Version 2.0, whose full text is in `sherpa-onnx-LICENSE.txt` and at http://www.apache.org/licenses/LICENSE-2.0. None of them ships a NOTICE file.
