#
# Nimble install test
#
# Copyright 2016 Federico Ceratto <federico.ceratto@gmail.com>
# Released under GPLv3 License, see LICENSE file
#

from algorithm import sortedByIt
import json
import marshal
import os
import osproc
import strutils
import streams
import sequtils
import times

template getEnvOrDefault(key, default: string): TaintedString =
  if existsEnv(key): getEnv(key) else: default

const
  template_path = "./templates"
  timeout = 60
  output_dir = "output"

let
  version_badge_tpl = readFile template_path / "version-template-blue.svg"
  nimble_binpath = getEnvOrDefault("NIMBLE_BINPATH", "/home/ubuntu/cache/Nim/bin/nimble")
  max_packages = getEnvOrDefault("MAX_PACKAGES", "-1").parseInt
  nim_commit = getEnvOrDefault("NIM_COMMIT", "unknown")
  nimble_commit = getEnvOrDefault("NIMBLE_COMMIT", "unknown")

type
  Pkg = tuple[name, url: string]
  TestResult* {.pure.} = enum
    OK, FAIL, TIMEOUT
  InstRep = object of RootObj
    title, url, version: string
    test_result: TestResult

include "templates/nimble_install_test_report.tmpl"
include "templates/nimble_install_test_output.tmpl"

proc gen_output_path(pkg_name, nim_version, fname: string): string =
  ## Generate output filename
  ## Path convention:
  ##   <pkg_name> / version.svg
  ##   <pkg_name> / [nimdevel|nimstable] / [status.svg|output.html]
  #assert nim_version in {"devel", "stable"}
  #assert fname in {"version.svg", "status.svg", "output.html"}
  if fname == "version.svg":
    return output_dir / pkg_name / fname
  return output_dir / pkg_name / "nim$#" % nim_version / fname

proc writeout(fn, content: string) =
  ## Write to file, create dirs if needed
  fn.parentDir.createDir
  fn.writeFile(content)

proc gmtime(): string =
  return $getGmTime(getTime())

proc load_packages(): seq[Pkg] =
  result = @[]
  let pkg_list = parseJson(readFile("packages.json"))
  for pdata in pkg_list:
    if pdata.hasKey("name"):
      if pdata.hasKey("web"):
        result.add((pdata["name"].getStr(), pdata["web"].getStr()))
      else:
        result.add((pdata["name"].getStr(), ""))
  result = result.sortedByIt(it[0])
  # result = result[0..1]

proc write_status_badge(output: string, pkg: Pkg) =
  ## Write stderr/stdout output
  let
    page = generate_install_report_output_page(pkg.name, output, gmtime())
    ofn = gen_output_path(pkg.name, "devel", "output.html")
  ofn.writeout page

proc extract_version(output: string, pkg: Pkg): string =
  let marker = "Installing $#-" % pkg.name
  for line in output.splitLines():
    if line.startsWith(marker):
      return line[marker.len..^1]

  return "None"

proc write_version_badge(version: string, pkg: Pkg) =
  let
    badge = version_badge_tpl % [version, version]
    ofn = gen_output_path(pkg.name, "", "version.svg")
  ofn.writeout badge

proc main() =
  createDir(output_dir)

  let packages = load_packages()
  var installation_reports: seq[InstRep] = @[]

  for pkg in packages:
    if max_packages != -1 and installation_reports.len == max_packages:
        break

    let tmp_dir = "/tmp/nimble_install_test/" / pkg.name
    createDir(tmp_dir)
    echo "Processing ", $pkg.name
    let
      p = startProcess(
        nimble_binpath,
        args=["install", $pkg.name, "--nimbleDir=$#" % tmp_dir, "-y"],
        options={poStdErrToStdOut}
      )

    var exit_code = -3
    for time_cnt in 0..timeout:
      exit_code = p.peekExitCode()
      if exit_code == -1:
        sleep(1000)
      else:
        break

    let test_result =
      case exit_code
      of -1:
        p.kill()
        TestResult.TIMEOUT
      of 0:
        TestResult.OK
      else:
        TestResult.FAIL

    echo $test_result
    discard p.waitForExit()
    let
      output = p.outputStream().readAll()
      tpl_fname = if test_result == TestResult.OK: "success.svg" else: "fail.svg"
      ofn = gen_output_path(pkg.name, "devel", "status.svg")
    write_status_badge(output, pkg)
    ofn.parentDir.createDir
    copyFile(template_path / tpl_fname, ofn)

    let version = extract_version(output, pkg)
    write_version_badge(version, pkg)

    let r = InstRep(title: pkg.name, url: pkg.url, test_result: test_result,
      version: version)
    installation_reports.add r
    assert tmp_dir.len > 10
    removeDir(tmp_dir)


  let tstamp = $getGmTime(getTime())
  echo "Writing output"
  let
    page = generateHTMLPage(installation_reports, tstamp, nim_commit, nimble_commit)
    ofn = output_dir / "nimble_install_report.html"
  ofn.writeout page
  try:
    writeout(output_dir / "nimble_install_report.json", $$installation_reports)
  except:
    echo getCurrentExceptionMsg()




when isMainModule:
  main()
