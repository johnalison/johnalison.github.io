// fix-tables.js
// org-mode journal tables use "| --- | --- |" as a header separator, which
// org-publish exports as a plain <td> row instead of a <thead> boundary.
// This script detects those rows and rebuilds the table with proper thead/tbody.
// It also links the first-column day numbers on monthly pages to the
// corresponding daily journal entry.

document.addEventListener('DOMContentLoaded', function () {

  // ── 0. Detect monthly page and extract month/year ──────────────────────
  // Two URL patterns:
  //   /Notes/january_2026-TIMESTAMP.html
  //   /Journal/May2025.html  or  /Journal/February 2025.html
  var monthNames = ['january','february','march','april','may','june',
                    'july','august','september','october','november','december'];
  var dayNames   = ['Sunday','Monday','Tuesday','Wednesday',
                    'Thursday','Friday','Saturday'];

  var monthIdx = -1, year = -1;
  var path = decodeURIComponent(window.location.pathname);

  var m = path.match(/\/Notes\/([a-z]+)_(\d{4})-\d+\.html$/);
  if (m) {
    monthIdx = monthNames.indexOf(m[1]);
    year     = parseInt(m[2], 10);
  } else {
    // Matches /Journal/May2025.html  AND  /Journal/2024/July 2024.html
    m = path.match(/\/Journal\/(?:\d{4}\/)?([A-Za-z]+)\s*(\d{4})\.html$/);
    if (m) {
      monthIdx = monthNames.indexOf(m[1].toLowerCase());
      year     = parseInt(m[2], 10);
    }
  }

  var isMonthlyPage = (monthIdx !== -1 && year !== -1);
  if (isMonthlyPage) {
    document.body.classList.add('monthly-page');
  }

  // ── 1. Fix org separator rows into proper thead/tbody ──────────────────
  document.querySelectorAll('table').forEach(function (table) {
    var rows = Array.from(table.querySelectorAll('tr'));

    function isSeparatorRow(row) {
      var cells = Array.from(row.querySelectorAll('td'));
      if (cells.length === 0) return false;
      return cells.every(function (td) {
        var text = td.textContent;
        return /^[-\u00a0\s]+$/.test(text) && /[-]/.test(text);
      });
    }

    var sepIdx = rows.findIndex(isSeparatorRow);
    if (sepIdx < 0) return;

    var headerRows = rows.slice(0, sepIdx);
    var bodyRows   = rows.slice(sepIdx + 1);

    var thead = document.createElement('thead');
    var tbody = document.createElement('tbody');

    headerRows.forEach(function (row) {
      var newRow = document.createElement('tr');
      Array.from(row.querySelectorAll('td')).forEach(function (td) {
        var th = document.createElement('th');
        th.innerHTML = td.innerHTML;
        th.className = td.className;
        newRow.appendChild(th);
      });
      thead.appendChild(newRow);
    });

    bodyRows.forEach(function (row) {
      tbody.appendChild(row.cloneNode(true));
    });

    table.innerHTML = '';
    table.appendChild(thead);
    table.appendChild(tbody);
  });

  // ── 2. Link day-number cells to daily journal entries ──────────────────
  if (!isMonthlyPage) return;

  var monthCap = monthNames[monthIdx].charAt(0).toUpperCase() +
                 monthNames[monthIdx].slice(1);         // "May"
  var monthMM  = String(monthIdx + 1).padStart(2, '0'); // "05"

  document.querySelectorAll('tbody tr').forEach(function (row) {
    var firstCell = row.querySelector('td:first-child');
    if (!firstCell) return;
    var text = firstCell.textContent.trim();
    var dayMatch = text.match(/^(\d+)/);
    if (!dayMatch) return;
    var day = parseInt(dayMatch[1], 10);

    var date = new Date(year, monthIdx, day);
    if (date.getMonth() !== monthIdx) return;

    var dayName = dayNames[date.getDay()];
    var dayDD   = String(day).padStart(2, '0');
    var href    = '/Journal/' + year + '/' + monthMM + '-' + monthCap + '/' +
                  dayDD + '-' + monthCap + '-' + year + '-' + dayName + '.html';

    var a = document.createElement('a');
    a.href = href;
    a.textContent = text;
    firstCell.textContent = '';
    firstCell.appendChild(a);
  });

});
