#!/usr/bin/env python3
"""Prepare/verify one fpw CLOB flag change without printing datasource XML or credentials.
Does not contact Docker, stop services, or apply configuration.
"""
import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from xml.parsers import expat
from xml.etree import ElementTree

def locate(data):
    frames = []
    targets = []
    parser = expat.ParserCreate()
    parser.SetParamEntityParsing(expat.XML_PARAM_ENTITY_PARSING_NEVER)
    def start(name, attrs):
        frames.append((name, attrs))
        if (name == "boolean" and len(frames) > 1
            and frames[-2][0] == "var" and frames[-2][1].get("name") == "disable_clob"
            and any(tag == "var" and fields.get("name", "").lower() == "fpw" for tag, fields in frames[:-2])):
            begin = parser.CurrentByteIndex
            finish = data.find(b">", begin) + 1
            if finish <= begin:
                raise ValueError("Invalid target element")
            tag = data[begin:finish]
            matches = list(re.finditer(rb"\bvalue\s*=\s*(['\"])(true|false)\1", tag))
            if len(matches) != 1:
                raise ValueError("Target boolean value is not explicit")
            match = matches[0]
            targets.append((begin + match.start(2), begin + match.end(2), match.group(2)))
    def end(name):
        frames.pop()
    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.Parse(data, True)
    if len(targets) != 1:
        raise ValueError("Expected exactly one fpw disable_clob boolean")
    return targets[0]

def sha(data):
    return hashlib.sha256(data).hexdigest()

def compare(before, after):
    a, b, old = locate(before)
    c, d, new = locate(after)
    outside_before = before[:a] + b"<CLOB_FLAG>" + before[b:]
    outside_after = after[:c] + b"<CLOB_FLAG>" + after[d:]
    if old != b"true" or new != b"false" or outside_before != outside_after:
        raise ValueError("Candidate differs outside the approved true-to-false CLOB value")
    return {"datasource":"fpw", "before_disable_clob":True, "after_disable_clob":False,
            "only_approved_value_changed":True, "before_sha256":sha(before),
            "after_sha256":sha(after), "non_clob_bytes_sha256":sha(outside_before),
            "before_bytes":len(before), "after_bytes":len(after)}

def semantic_value(element):
    children = [semantic_value(child) for child in element]
    if element.tag == "struct":
        children.sort(key=lambda value: json.dumps(value[1]))
    return [element.tag, sorted(element.attrib.items()),
            element.text if element.text and element.text.strip() else "", children]

def compare_runtime(before, current):
    a,b,old = locate(before)
    if old != b"true":
        raise ValueError("Expected approved pre-change baseline")
    expected = before[:a]+b"false"+before[b:]
    report = compare(before,expected)
    expected_value = json.dumps(semantic_value(ElementTree.fromstring(expected)),separators=(",",":")).encode()
    current_value = json.dumps(semantic_value(ElementTree.fromstring(current)),separators=(",",":")).encode()
    if expected_value != current_value:
        raise ValueError("Runtime datasource values differ from the one-field approved change")
    report.update({"runtime_semantics_match":True,"runtime_sha256":sha(current),
                   "all_settings_semantic_sha256":sha(current_value)})
    return report

def write_private(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as stream:
        stream.write(data)

def self_test():
    source = b"<wddxPacket><var name='fpw'><struct><var name='password'><string>synthetic-only</string></var><var name='disable_clob'><boolean value='true'/></var></struct></var><var name='other'><var name='disable_clob'><boolean value='true'/></var></var></wddxPacket>"
    a,b,_ = locate(source)
    candidate = source[:a]+b"false"+source[b:]
    assert compare(source,candidate)["only_approved_value_changed"]
    failures=0
    for bad in (source.replace(b"name='fpw'",b"name='absent'"), source.replace(b"</wddxPacket>",b"<var name='fpw'><var name='disable_clob'><boolean value='true'/></var></var></wddxPacket>")):
        try: locate(bad)
        except ValueError: failures += 1
    assert failures == 2
    try: compare(source,candidate.replace(b"synthetic-only",b"changed"))
    except ValueError: return {"self_test":"PASS","checks":4}
    raise AssertionError("Unrelated change was accepted")

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode",choices=["prepare","verify","verify-runtime","self-test"])
    parser.add_argument("--input")
    parser.add_argument("--output")
    parser.add_argument("--candidate")
    parser.add_argument("--report")
    args=parser.parse_args()
    if args.mode == "self-test":
        print(json.dumps(self_test())); return
    if not args.input:
        raise ValueError("A protected input path is required")
    before=Path(args.input).read_bytes()
    if args.mode == "prepare":
        if not args.output or not args.report:
            raise ValueError("Protected output and report paths are required")
        a,b,old=locate(before)
        if old != b"true":
            raise ValueError("Current fpw disable_clob is not true; stop and review")
        after=before[:a]+b"false"+before[b:]
        report=compare(before,after)
        write_private(args.output,after)
        write_private(args.report,(json.dumps(report,indent=2)+"\n").encode())
    else:
        if not args.candidate:
            raise ValueError("A protected candidate path is required")
        report=(compare_runtime if args.mode == "verify-runtime" else compare)(before,Path(args.candidate).read_bytes())
    print(json.dumps(report))

if __name__ == "__main__":
    try: main()
    except Exception as error:
        # Error type/message only; never emit input bytes or any XML element contents.
        print(json.dumps({"success":False,"error_type":type(error).__name__,"message":str(error)}),file=sys.stderr)
        sys.exit(1)
