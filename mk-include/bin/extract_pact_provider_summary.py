#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import os
import re
import xml.etree.ElementTree as ET

# Pact provider tests color their shell output via control characters
# so we'll use this regex to remove them, because colored output looks like
# weird characters in junit xml.
# Regex taken from here:
# https://stackoverflow.com/questions/14693701/how-can-i-remove-the-ansi-escape-sequences-from-a-string-in-python
ANSI_ESCAPE = re.compile(r'''
    \x1B  # ESC
    (?:   # 7-bit C1 Fe (except CSI)
        [@-Z\\-_]
    |     # or [ for CSI, followed by a control sequence
        \[
        [0-?]*  # Parameter bytes
        [ -/]*  # Intermediate bytes
        [@-~]   # Final byte
    )
''', re.VERBOSE)


def write_pact_summary_file(testsuites, output_file):
    pact_summary = ""
    for sysout in testsuites.iter("system-out"):
        inside_pact_summary = False
        lines = sysout.text.splitlines(keepends=True)
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("Verifying a pact between") or stripped.startswith("The pact at http"):
                # found a beginning of a pact output.
                inside_pact_summary = True
            if inside_pact_summary:
                pact_summary += line
    if pact_summary:
        pact_summary = ANSI_ESCAPE.sub("", pact_summary)
        summary = f'**Pact provider test summary:**\n```\n{pact_summary}```'
        if output_file:
            print(f"Writing pact provider test summary to file '{output_file}'")
            try:
                os.makedirs(os.path.dirname(output_file), exist_ok=True)
                with open(output_file, "w") as f:
                    f.write(summary)
                print(f"Successfully wrote provider test summary to file '{output_file}'")
            except FileNotFoundError:
                print(f"Failed to write pact provider test summary to '{output_file}', file not found")
                return
        else:
            print(pact_summary)
    else:
        print("No pact provider tests found, skip writing summary.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('file', metavar='FILE', help='file to read')
    parser.add_argument('-o', '--output', help='where to write the output. If empty, print to stdout')
    args = parser.parse_args()
    tree = ET.parse(args.file)
    testsuites = tree.getroot()
    write_pact_summary_file(testsuites, args.output)
