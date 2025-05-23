FROM ubuntu:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
        wget \
        curl \
        bcftools \
        tabix \ 
        python3.12 \
        python3.12-venv \
        python3-pip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
RUN ln -sf /usr/bin/python3.12 /usr/bin/python

# Create a working directory
WORKDIR /app

# Copy
COPY bin poetry.lock pyproject.toml ./

# Install dependencies
RUN python -m pip install --break-system-package --no-cache-dir poetry poetry-plugin-export && \
    python -m poetry export --without-hashes --format=requirements.txt -o requirements.txt && \
    python -m pip install --no-cache-dir --break-system-package -r requirements.txt

# Change mode of bin files
COPY bin/*.py bin/*.py
RUN chmod +x bin/*.py

# Set the default command
CMD ["/bin/bash"]
