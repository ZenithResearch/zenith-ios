"""Export public read response fixtures from a selected Devgraph source checkout.

No server, identity, credential, policy registry or live graph is accessed.
"""
import argparse
import json
import sys
import subprocess
from datetime import datetime, timezone
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--devgraph-source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
subprocess.run(['git','-C',str(args.devgraph_source),'diff','--exit-code','HEAD','--','src/devgraph/auth/monitor_read.py','src/devgraph/todo_views.py','src/devgraph/model','src/devgraph/storage','src/devgraph/workflows.py'],check=True,stdout=subprocess.DEVNULL)
sys.path.insert(0, str(args.devgraph_source / 'src'))
from devgraph.auth.monitor_read import MonitorWorkGrant, project_monitor_read
from devgraph.model.repository import WorkObjectRepository
from devgraph.model.work import Todo, Task
from devgraph.storage.memory import MemoryGraphStorage

stamp = dict(created_at=datetime(2026,10,13,tzinfo=timezone.utc), updated_at=datetime(2026,10,13,tzinfo=timezone.utc))
storage = MemoryGraphStorage()
repository = WorkObjectRepository(storage)
repository.create(Todo(id='first', title='First Todo', description='Full Todo description', priority=2, progress='in_progress', workflow_json=None, **stamp))
repository.create(Todo(id='second', title='Second Todo', priority=1, progress=None, workflow_json=None, **stamp))
repository.create(Task(id='task', title='Visible task', progress='done', workflow_json=None, **stamp))
storage.create_edge('Todo','first','BLOCKS','Task','task')
grant = MonitorWorkGrant.model_validate(dict(scope='devgraph.work.read', operations=['list','get','relationships'], relationship_types=['children','parent','blocked','blockers'], work_kinds=['Todo','Task'], include_archived=False))
page = project_monitor_read(storage, [grant], '/todos/v2?kind=Todo&limit=1')
next_page = project_monitor_read(storage, [grant], '/todos/v2?kind=Todo&limit=1&after=' + page['next_cursor'] + '&revision=' + page['revision'])
revision = subprocess.run(['git','-C',str(args.devgraph_source),'rev-parse','HEAD'],check=True,capture_output=True,text=True).stdout.strip()
result = dict(devgraph_revision=revision, schema='zenith.read-contract-fixtures.v1', grant=grant.model_dump(mode='json',exclude_defaults=True), page=page, next_page=next_page, detail=project_monitor_read(storage,[grant],'/todos/v2/Todo/first'), related=project_monitor_read(storage,[grant],'/work/Todo/first/relationships/blocked'))
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
