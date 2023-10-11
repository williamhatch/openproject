// -- copyright
// OpenProject is an open source project management software.
// Copyright (C) 2012-2023 the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import {
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  ElementRef,
  EventEmitter,
  forwardRef,
  HostBinding,
  Injector,
  Input,
  Output,
  ViewChild,
  ViewEncapsulation,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { merge, Observable, of } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import { ID } from '@datorama/akita';
import { HalResourceService } from 'core-app/features/hal/services/hal-resource.service';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { HalResourceNotificationService } from 'core-app/features/hal/services/hal-resource-notification.service';
import { ApiV3Service } from 'core-app/core/apiv3/api-v3.service';
import { ApiV3ListFilter, listParamsString } from 'core-app/core/apiv3/paths/apiv3-list-resource.interface';
import { populateInputsFromDataset } from 'core-app/shared/components/dataset-inputs';

import { IProjectAutocompleteItem } from './project-autocomplete-item';
import { flattenProjectTree } from './flatten-project-tree';
import { getPaginatedResults } from 'core-app/core/apiv3/helpers/get-paginated-results';
import { IProject } from 'core-app/core/state/projects/project.model';
import { IHALCollection } from 'core-app/core/apiv3/types/hal-collection.type';
import { buildTree } from 'core-app/shared/components/autocompleter/project-autocompleter/insert-in-list';
import { recursiveSort } from 'core-app/shared/components/autocompleter/project-autocompleter/recursive-sort';

export const projectsAutocompleterSelector = 'op-project-autocompleter';

export interface IProjectAutocompleterData {
  id:ID;
  href:string;
  name:string;
}

@Component({
  templateUrl: './project-autocompleter.component.html',
  styleUrls: ['./project-autocompleter.component.sass'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  encapsulation: ViewEncapsulation.None,
  selector: projectsAutocompleterSelector,
  providers: [{
    provide: NG_VALUE_ACCESSOR,
    useExisting: forwardRef(() => ProjectAutocompleterComponent),
    multi: true,
  }],
})
export class ProjectAutocompleterComponent implements ControlValueAccessor {
  @HostBinding('class.op-project-autocompleter') public className = true;

  @HostBinding('class.op-project-autocompleter_inline')
  public get inlineClass():boolean {
    return this.isInlineContext;
  }

  projectTracker = (item:IProjectAutocompleteItem):ID => item.href || item.id;

  // Load all projects as default
  @Input() public url:string = this.apiV3Service.projects.path;

  @Input() public name = '';

  @Input() public focusDirectly = false;

  @Input() public openDirectly = false;

  @Input() public multiple = false;

  @Input() public dropdownPosition:'bottom'|'top'|'auto' = 'auto';

  // ID that should be set on the input HTML element. It is used with
  // <label> tags that have `for=""` set
  @Input() public labelForId = '';

  @Input() public apiFilters:ApiV3ListFilter[] = [];

  @Input() public placeholder:string = this.I18n.t('js.autocompleter.project.placeholder');

  @Input() public appendTo = '';

  @Input() public isInlineContext = false;

  @Input() public hiddenFieldAction = '';

  @Input() public clearable?:boolean = true;

  dataLoaded = false;

  projects:IProjectAutocompleteItem[];

  // This function allows mapping of the results before they are fed to the tree
  // structuring and destructuring algorithms used internally the this component
  // to show the tree structure. By default it does not do much, but it is
  // overwritable so additional filtering or transforming can be done on the
  // API result set.
  @Input()
  public mapResultsFn:(projects:IProjectAutocompleteItem[]) => IProjectAutocompleteItem[] = (projects) => projects;

  @Input() public value:IProjectAutocompleterData|IProjectAutocompleterData[]|null;

  get plainValue():ID|ID[] {
    return (Array.isArray(this.value) ? this.value?.map((i) => i.id) : this.value?.id) || '';
  }

  /* eslint-disable-next-line @angular-eslint/no-output-rename */
  @Output('valueChange') valueChange = new EventEmitter<IProjectAutocompleterData|IProjectAutocompleterData[]|null>();

  @Output() cancel = new EventEmitter();

  @ViewChild('hiddenInput') hiddenInput:ElementRef;

  constructor(
    public elementRef:ElementRef,
    protected halResourceService:HalResourceService,
    protected I18n:I18nService,
    protected halNotification:HalResourceNotificationService,
    readonly http:HttpClient,
    readonly pathHelper:PathHelperService,
    readonly apiV3Service:ApiV3Service,
    readonly injector:Injector,
    readonly cdRef:ChangeDetectorRef,
  ) {
    populateInputsFromDataset(this);
  }

  private matchingItems(elements:IProjectAutocompleteItem[], matching:string):Observable<IProjectAutocompleteItem[]> {
    let filtered:IProjectAutocompleteItem[];

    if (matching === '' || !matching) {
      filtered = elements;
    } else {
      const lowered = matching.toLowerCase();
      filtered = elements.filter((el) => el.name.toLowerCase().includes(lowered));
    }

    return of(filtered);
  }

  private disableSelectedItems(
    projects:IProjectAutocompleteItem[],
    value:IProjectAutocompleterData|IProjectAutocompleterData[]|null,
  ) {
    if (!this.multiple) {
      return projects;
    }

    const normalizedValue = (value || []);
    const arrayedValue = (Array.isArray(normalizedValue) ? normalizedValue : [normalizedValue]).map((p) => p.href || p.id);
    return projects.map((project) => {
      const isSelected = !!arrayedValue.find((selected) => selected === this.projectTracker(project));
      return {
        ...project,
        disabled: isSelected || project.disabled,
      };
    });
  }

  public getAvailableProjects(searchTerm:string):Observable<IProjectAutocompleteItem[]> {
    if (this.dataLoaded === true) {
      return this.matchingItems(this.projects, searchTerm).pipe(
        map(this.mapResultsFn),
        map((projects) => projects.sort((a, b) => a.ancestors.length - b.ancestors.length)),
        map((projects) => buildTree(projects)),
        map((projects) => recursiveSort(projects)),
        map((projectTreeItems) => flattenProjectTree(projectTreeItems)),
        switchMap(
          (projects) => merge(of([]), this.valueChange).pipe(
            map(() => this.disableSelectedItems(projects, this.value)),
          ),
        ),
      );
    }
    return getPaginatedResults<IProject>(
      (params) => {
        const filters:ApiV3ListFilter[] = [...this.apiFilters];

        if (searchTerm.length) {
          filters.push(['typeahead', '**', [searchTerm]]);
        }

        const url = new URL(this.url, window.location.origin);
        const fullParams = {
          filters,
          select: [
            'elements/id',
            'elements/name',
            'elements/identifier',
            'elements/self',
            'elements/ancestors',
            'total',
            'count',
            'pageSize',
          ],
          ...params,
        };
        const collectionURL = `${listParamsString(fullParams)}&${url.searchParams.toString()}`;
        url.search = '';
        return this.http.get<IHALCollection<IProject>>(url.toString() + collectionURL);
      },
    )
      .pipe(
        map((projects) => projects.map((project) => ({
          id: project.id,
          href: project._links.self.href,
          name: project.name,
          disabled: false,
          ancestors: project._links.ancestors,
          children: [],
        }))),
        map(this.mapResultsFn),
        map((projects) => {
          this.dataLoaded = true;
          this.projects = projects;
          return projects.sort((a, b) => a.ancestors.length - b.ancestors.length);
        }),
        map((projects) => buildTree(projects)),
        map((projects) => recursiveSort(projects)),
        map((projectTreeItems) => flattenProjectTree(projectTreeItems)),
        switchMap(
          (projects) => merge(of([]), this.valueChange).pipe(
            map(() => this.disableSelectedItems(projects, this.value)),
          ),
        ),
      );
  }

  projectSelected(value:IProjectAutocompleterData|IProjectAutocompleterData[]|null):void {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access,@typescript-eslint/no-unsafe-call
    this.writeValue(value);
    this.onChange(value);
    this.onTouched(value);
    this.valueChange.emit(value);
    const input = this.hiddenInput.nativeElement as HTMLInputElement|undefined;
    if (input) {
      input.value = this.plainValue as string;
      input.dispatchEvent(new Event('change'));
    }
    this.cdRef.detectChanges();
  }

  writeValue(value:IProjectAutocompleterData|IProjectAutocompleterData[]|null):void {
    this.value = value;
  }

  onChange = (_:IProjectAutocompleterData|IProjectAutocompleterData[]|null):void => {};

  onTouched = (_:IProjectAutocompleterData|IProjectAutocompleterData[]|null):void => {};

  registerOnChange(fn:(_:IProjectAutocompleterData|IProjectAutocompleterData[]|null) => void):void {
    this.onChange = fn;
  }

  registerOnTouched(fn:(_:IProjectAutocompleterData|IProjectAutocompleterData[]|null) => void):void {
    this.onTouched = fn;
  }
}
