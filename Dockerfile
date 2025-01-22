FROM docker.io/riscv64/ubuntu:24.04 as build 
VOLUME /output

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    python3.12 python3.12-dev python3.12-venv python3-pip \
    build-essential \
    git \
    make \
    ca-certificates \
    libopenblas-dev \
    libopenblas64-dev \
    libssl-dev cmake ninja-build patchelf libtiff5-dev libjpeg8-dev libopenjp2-7-dev zlib1g-dev \
    libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python3-tk \
    libharfbuzz-dev libfribidi-dev libxcb1-dev meson \
    sudo && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN groupadd riscv64 && \
    useradd -s /bin/bash -g riscv64 -m -k /dev/null riscv64 && \
    usermod -a -G sudo riscv64 && \
    echo "riscv64 ALL = NOPASSWD : ALL" >> /etc/sudoers.d/riscv64

USER riscv64
WORKDIR /Pytorch-Wildlife

RUN git clone --depth 1 https://github.com/pytorch/pytorch.git && cd pytorch && \
  git submodule update --init --recursive --depth 1 && cd .. && \
  git clone --depth 1 https://github.com/pytorch/vision.git && \
  git clone --depth 1 https://github.com/pytorch/audio.git && \
  git clone --depth 1 https://github.com/microsoft/CameraTraps


# pytorch
RUN python3.12 -m venv venv && source venv/bin/activate && \
  pip3 install --upgrade pip && \
  pip3 install --upgrade setuptools wheel auditwheel && \
  MAX_CONCURRENCY=64 pip3 wheel --wheel-dir /Pytorch-Wildlife/ cffi dataclasses future oldest-supported-numpy pillow pyyaml requests six typing_extensions tqdm && \
  ls /Pytorch-Wildlife/ && pip3 install *whl && cd /Pytorch-Wildlife/pytorch && \
  python3 setup.py build && \
  python3 setup.py develop && \
  python3 setup.py bdist_wheel

# pytorch-audio
#RUN sudo DEBIAN_FRONTEND=noninteractive apt-get update
#RUN sudo DEBIAN_FRONTEND=noninteractive apt-get install -y libssl-dev cmake ninja-build patchelf libtiff5-dev libjpeg8-dev libopenjp2-7-dev zlib1g-dev \
#    libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python3-tk \
#    libharfbuzz-dev libfribidi-dev libxcb1-dev meson
RUN source venv/bin/activate && \
  cd /Pytorch-Wildlife/audio/ && \
  USE_FFMPEG=0 python3 setup.py build && \
  USE_FFMPEG=0 python3 setup.py bdist_wheel

# pytorch-vision
RUN source venv/bin/activate && \
  cd /Pytorch-Wildlife/vision/ && \
  python3 setup.py build && \
  python3 setup.py bdist_wheel

FROM docker.io/riscv64/ubuntu:24.04 as wildlife
VOLUME /output

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    python3.12 python3.12-dev python3.12-venv python3-pip \
    build-essential \
    git \
    make \
    ca-certificates \
    libopenblas-dev \
    libopenblas64-dev \
    sudo && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN groupadd riscv64 && \
    useradd -s /bin/bash -g riscv64 -m -k /dev/null riscv64 && \
    usermod -a -G sudo riscv64 && \
    echo "riscv64 ALL = NOPASSWD : ALL" >> /etc/sudoers.d/riscv64

USER riscv64
WORKDIR /wildlife

RUN python3.12 -m venv venv

COPY --from=build /Pytorch-Wildlife/pytorch/dist/*whl /wildlife
COPY --from=build /Pytorch-Wildlife/audio/dist/*whl /wildlife
COPY --from=build /Pytorch-Wildlife/vision/dist/*whl /wildlife
COPY --from=build /Pytorch-Wildlife/*whl /wildlife

RUN source venv/bin/activate && \
  pip3 install --upgrade pip && pip3 install *whl
