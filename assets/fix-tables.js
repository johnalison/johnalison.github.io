// fix-tables.js
// org-mode journal tables use "| --- | --- |" as a header separator, which
// org-publish exports as a plain <td> row instead of a <thead> boundary.
// This script detects those rows and rebuilds the table with proper thead/tbody.

document.addEventListener('DOMContentLoaded', function () {
  document.querySelectorAll('table').forEach(function (table) {
    var rows = Array.from(table.querySelectorAll('tr'));

    // A separator row is one where every cell contains only dashes/spaces
    // (org exports non-breaking spaces \u00a0 for empty cells).
    function isSeparatorRow(row) {
      var cells = Array.from(row.querySelectorAll('td'));
      if (cells.length === 0) return false;
      return cells.every(function (td) {
        var text = td.textContent;
        return /^[-\u00a0\s]+$/.test(text) && /[-]/.test(text);
      });
    }

    var sepIdx = rows.findIndex(isSeparatorRow);
    if (sepIdx < 0) return; // no separator — leave table alone

    var headerRows = rows.slice(0, sepIdx);
    var bodyRows   = rows.slice(sepIdx + 1);

    var thead = document.createElement('thead');
    var tbody = document.createElement('tbody');

    // Rebuild header rows using <th> instead of <td>
    headerRows.forEach(function (row) {
      var newRow = document.createElement('tr');
      Array.from(row.querySelectorAll('td')).forEach(function (td) {
        var th = document.createElement('th');
        th.innerHTML  = td.innerHTML;
        th.className  = td.className;
        newRow.appendChild(th);
      });
      thead.appendChild(newRow);
    });

    // Keep body rows as-is
    bodyRows.forEach(function (row) {
      tbody.appendChild(row.cloneNode(true));
    });

    table.innerHTML = '';
    table.appendChild(thead);
    table.appendChild(tbody);
  });
});
