#!/usr/bin/env python3
import sys
import logging
import os

logging.basicConfig(level=logging.INFO)

logging.info(f"sys.executable: {sys.executable}")
logging.info(f"sys.prefix: {sys.prefix}")
logging.info(f"sys.path: {sys.path}")
logging.info(f"os.environ['VIRTUAL_ENV']: {os.environ.get('VIRTUAL_ENV')}")
logging.info(f"os.environ['PYTHONPATH']: {os.environ.get('PYTHONPATH')}")


