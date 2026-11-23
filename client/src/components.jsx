import { useState } from 'react';

// React escapes text in JSX automatically, so database values rendered
// with {value} can't inject HTML (XSS). Avoid dangerouslySetInnerHTML.

export function StatCards({ stats }) {
  const items = [
    ['Facilities', stats.facilities],
    ['Batches', stats.batches],
    ['Total recovered (kg)', stats.total_recovered_kg],
  ];
  return (
    <section className="cards">
      {items.map(([label, value]) => (
        <div className="card" key={label}>
          <b>{Number(value).toLocaleString()}</b>
          <small>{label}</small>
        </div>
      ))}
    </section>
  );
}

// Generic table: `columns` = [{key,label}], `action` = optional (row) => element
export function DataTable({ title, columns, rows, action }) {
  return (
    <section>
      <h2>{title}</h2>
      <div className="overflow">
        <table>
          <thead>
            <tr>
              {columns.map((c) => <th key={c.key}>{c.label}</th>)}
              {action && <th />}
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr><td colSpan={columns.length + 1}>No data yet</td></tr>
            )}
            {rows.map((row, i) => (
              <tr key={row.batch_id ?? row.facility_id ?? row.material_id ?? i}>
                {columns.map((c) => <td key={c.key}>{row[c.key] ?? '—'}</td>)}
                {action && <td>{action(row)}</td>}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

export function BatchForm({ facilities, onSubmit }) {
  const [facilityId, setFacilityId] = useState('');
  const [code, setCode] = useState('');

  const submit = async (e) => {
    e.preventDefault();
    const ok = await onSubmit({ facility_id: facilityId, batch_code: code });
    if (ok) setCode('');
  };

  return (
    <form onSubmit={submit}>
      <select value={facilityId} onChange={(e) => setFacilityId(e.target.value)} required>
        <option value="">Select facility</option>
        {facilities.map((f) => (
          <option key={f.facility_id} value={f.facility_id}>{f.facility_name} ({f.city})</option>
        ))}
      </select>
      <input value={code} onChange={(e) => setCode(e.target.value)}
             placeholder="Batch code e.g. BATCH-2026-006" required />
      <button>Create batch</button>
    </form>
  );
}

export function RecoveryForm({ openBatches, materials, onSubmit }) {
  const [batchId, setBatchId] = useState('');
  const [materialId, setMaterialId] = useState('');
  const [weight, setWeight] = useState('');

  const submit = async (e) => {
    e.preventDefault();
    const ok = await onSubmit({ batch_id: batchId, material_id: materialId, weight });
    if (ok) setWeight('');
  };

  return (
    <section>
      <h2>Record recovered material</h2>
      <form onSubmit={submit}>
        <select value={batchId} onChange={(e) => setBatchId(e.target.value)} required>
          <option value="">Select open batch</option>
          {openBatches.map((b) => <option key={b.batch_id} value={b.batch_id}>{b.batch_code}</option>)}
        </select>
        <select value={materialId} onChange={(e) => setMaterialId(e.target.value)} required>
          <option value="">Select material</option>
          {materials.map((m) => <option key={m.material_id} value={m.material_id}>{m.material_name}</option>)}
        </select>
        <input type="number" step="0.01" min="0.01" value={weight}
               onChange={(e) => setWeight(e.target.value)} placeholder="Weight (kg)" required />
        <button>Add</button>
      </form>
    </section>
  );
}
